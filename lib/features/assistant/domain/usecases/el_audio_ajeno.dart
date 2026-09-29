import 'package:nexus/features/assistant/domain/entities/audio_frame.dart';
import 'package:nexus/features/oido/domain/usecases/como_se_le_llama.dart';

/// Qué hacer con lo que suena alrededor y no iba dirigido a Nexus.
///
/// 🔴 **Pasó, dos corridas seguidas y con la transcripción delante.** Con la
/// sesión de voz abierta, el micrófono recogió conversación de la habitación
/// —«sí, porque el otro muchacho fue el que hizo el servicio en el día»— y el
/// modelo la contestó. Peor todavía: el servicio la tomó por una interrupción y
/// **cortó lo que estaba diciendo** a media frase. Dos de los tres turnos de esa
/// sesión no pasaron por Claude, y ninguno de los dos se le había dicho a nadie.
///
/// Lo que se decide aquí es **quién manda en la interrupción**. Antes la decidía
/// el detector de voz del servicio: cualquier sonido con forma de habla cortaba
/// la respuesta. Ahora el servicio no interrumpe nunca —`NO_INTERRUPTION` en el
/// `setup`— y la decisión es de este lado, con la transcripción en la mano.
///
/// La regla es corta a propósito: **mientras Nexus habla, solo le interrumpe
/// quien le habla a ella**. Dos formas de hacerlo, y las dos son las que
/// cualquiera usa sin que se le explique:
///
/// - **Decirle su nombre.** Es lo que hace todo el mundo con un asistente.
/// - **Una palabra de control**: «para», «espera», «cállate», «repite». Son las
///   que se dicen justo cuando está hablando y hay que poder decirlas.
///
/// Lo que llegue mientras habla y no sea una de las dos, **se ignora entero**:
/// no va a Claude, su respuesta no suena y no cuenta como actividad —así la
/// sesión se cierra sola a los seis segundos en vez de quedarse abierta oyendo
/// la habitación—. Y se dice, que es la otra mitad: un turno tirado en silencio
/// se lee como que la voz no funciona.
///
/// **Y después de contestar, solo con su nombre.** Lo primero que dices se
/// atiende sin más: la sesión la abriste tú y va dirigido a ella por
/// construcción. Pero una vez que contestó, el micrófono sigue abierto y con el
/// del Mac —sin auriculares— recoge la sala entera: con la tele encendida
/// contestaba a la tele, y la conversación no se cerraba nunca porque cada
/// frase de fondo contaba como actividad (visto el 27 sep). Así que a partir de
/// ahí se sigue con «Ciel, ¿y mañana?». La excepción es cuando ella acaba
/// preguntando —«¿Lo regenero?»—: lo siguiente es tu respuesta, y un «sí» no
/// necesita nombre. Ver [pideSuNombre].
///
/// ## Y justo después de contestar, sin nombre (29 sep)
///
/// 🔴 **Esto revierte a medias una decisión suya, y la revirtió él el 29 sep.**
/// Lo de arriba —«tras contestar solo atiende lo que lleva su nombre», PR #449,
/// 1.28.0— lo pidió él por la tele. Al usarlo, la conversación dejó de ser una
/// conversación: después de cada respuesta había que volver a llamarla, y lo
/// comparó con un asistente de un vídeo que se sigue de corrido. Así que
/// **durante unos segundos después de que ella termine de hablar**
/// —[ventanaSinNombre]—, lo que digas le llega sin nombre.
///
/// Lo que protege de la tele sigue en pie, con dos condiciones que la tele no
/// cumple:
///
/// - **Voz cercana y clara**: al menos [trozosDeVozCercana] trozos del micro por
///   encima de [nivelDeVozCercana] **dentro de la ventana**. El micro de la
///   conversación llega con el eco cancelado, así que lo fuerte ahí es alguien
///   hablándole al Mac de cerca; la tele al otro lado de la sala se queda
///   debajo.
/// - **Solo justo después de ella**: pasada la ventana vuelve a exigir el
///   nombre, así que una frase de la tele un minuto después sigue sin colarse.
///
/// Se apaga en Ajustes › Oído, y vuelve a ser lo del 27 sep.
abstract final class ElAudioAjeno {
  /// Cuánto después de que ella calle se le puede seguir hablando sin su
  /// nombre. Ocho segundos: lo que tarda en ocurrírsete la repregunta —«¿y
  /// mañana?»— sin que la sala tenga tiempo de meter una frase entera.
  static const ventanaSinNombre = Duration(seconds: 8);

  /// Cuántos trozos de voz cercana —de ~100 ms— hacen falta dentro de la
  /// ventana para que cuente como que le hablas tú. Tres: una sílaba suelta o
  /// un golpe en la mesa no llegan; una palabra dicha de cerca, sí.
  static const trozosDeVozCercana = 3;

  /// Palabras con las que se corta a alguien que está hablando.
  ///
  /// **Es a propósito una lista más corta que la de cortesía** de
  /// [VoiceRouting]: «hola» o «gracias» no interrumpen a nadie, y con ellas
  /// dentro cualquier «gracias» de fondo volvería a cortar la respuesta — que es
  /// justo el fallo que esto viene a cerrar.
  static final _deControl = RegExp(
    r'\b(para|p[aá]rate|espera|esp[eé]rate|silencio|c[aá]llate|calla|'
    r'repite|rep[ií]telo|otra vez|d[eé]jalo|olv[ií]dalo|'
    r'stop|wait|hold on|be quiet|quiet|repeat|say that again|never mind)\b',
    caseSensitive: false,
  );

  /// A partir de qué volumen del micro un trozo es **voz cercana**: alguien
  /// hablándole al Mac desde su sitio, y no la tele o la habitación.
  ///
  /// En la escala de [AudioFrame.amplitude] —la raíz de la RMS, de 0 a 1—: 0,2
  /// es una RMS de 0,04, unos −28 dBFS, que es lo que da una voz normal a medio
  /// metro con el eco ya cancelado; la tele al otro lado de la sala se queda
  /// por debajo de 0,15. **Es un punto de partida, no una medida**: cada frase
  /// que se juzga con él deja su nivel en el registro —«voz · nivel de la
  /// frase»— para poder afinarlo con la sala de verdad.
  static const nivelDeVozCercana = 0.2;

  /// Si esto puede cortar lo que Nexus está diciendo.
  ///
  /// [agente] es cómo se llama ella en esta instalación —se puede cambiar en
  /// Ajustes—, y se acepta también «nexus» a secas: es el nombre del producto y
  /// el que sale solo cuando alguien no recuerda el que puso.
  static bool interrumpe(String frase, {String? agente}) {
    final limpia = _limpia(frase);
    if (limpia.isEmpty) return false;
    if (_deControl.hasMatch(limpia)) return true;
    return laNombra(frase, agente: agente);
  }

  /// Si en la frase está su nombre —o «nexus»—, sin contar las palabras de
  /// control.
  ///
  /// Es lo que se pide **después de contestar**: ahí «para» no vale, porque no
  /// hay nada que cortar y la tele dice «para mañana» cada dos frases.
  static bool laNombra(String frase, {String? agente}) {
    final limpia = _limpia(frase);
    if (limpia.isEmpty) return false;
    final palabras = limpia.split(' ');
    for (final nombre in {'nexus', ...?_nombre(agente)}) {
      if (RegExp('\\b${RegExp.escape(nombre)}\\b').hasMatch(limpia)) {
        return true;
      }
      // Como suena y no como se escribe: el servicio transcribe un nombre que
      // no conoce como le suena, y «Siel» es «Ciel».
      if (!nombre.contains(' ') &&
          palabras.any(
            (p) =>
                ComoSeLeLlama.comoSuena(p) == ComoSeLeLlama.comoSuena(nombre),
          )) {
        return true;
      }
    }
    return false;
  }

  /// Si la próxima frase tiene que llevar su nombre para atenderse.
  ///
  /// [sigueLaConversacion] es que empezaste a hablar de cerca justo después de
  /// que ella callara: ver «Y justo después de contestar, sin nombre», arriba.
  static bool pideSuNombre({
    required bool yaContesto,
    required bool preguntoElla,
    bool sigueLaConversacion = false,
  }) => yaContesto && !preguntoElla && !sigueLaConversacion;

  /// Si este turno se tira: llegó mientras hablaba —o cuando ya tenía que
  /// traer su nombre, ver [pideSuNombre]— y no iba con ella.
  static bool seIgnora(
    String frase, {
    required bool estabaHablando,
    bool teniaQueNombrarla = false,
    String? agente,
  }) {
    if (_limpia(frase).isEmpty) return false;
    if (estabaHablando) return !interrumpe(frase, agente: agente);
    return teniaQueNombrarla && !laNombra(frase, agente: agente);
  }

  static Iterable<String>? _nombre(String? agente) {
    final limpio = _limpia(agente ?? '');
    return limpio.isEmpty ? null : [limpio];
  }

  /// Sin signos y en minúsculas: la transcripción del servicio trae comas y
  /// puntos donde le parece, y «¿nexus?» tiene que valer igual que «nexus».
  static String _limpia(String frase) => frase
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[¿?¡!.,;:«»"]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
