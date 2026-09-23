/// Los cuatro estados del orbe y del horizonte. Cada uno cambia el tipo de
/// movimiento del orbe y el tipo de línea del horizonte, nunca solo el color
/// — es lo que permite distinguir el estado a tres metros.
enum NexusOrbState {
  /// En reposo: solo puntos, sin malla. Respira lento, giro casi imperceptible.
  sleep,

  /// Escuchando: la malla aparece, un anillo de voz rodea el orbe, el
  /// horizonte se vuelve onda.
  listen,

  /// Trabajando: gira mucho más rápido, dos anillos lo barren, el horizonte
  /// es un riel con un pulso que viaja.
  think,

  /// Pensando: el turno sigue en pie pero lleva rato sin decir una palabra.
  ///
  /// 🔴 **Es un estado propio porque el silencio se lee como un cuelgue.** Entre
  /// dos trozos de respuesta Claude puede pensar minutos —medido: tres minutos
  /// y treinta y ocho segundos en mitad de un turno que acabó bien— y hasta
  /// ahora la pantalla se quedaba diciendo «hablando» con media respuesta
  /// escrita y nada apareciendo. Se reportó dos veces como si se hubiera
  /// quedado pegado.
  ///
  /// Y con **su propio movimiento**, que es la regla de aquí arriba: el estado
  /// se distingue a tres metros o no se distingue. Gira despacio —entre dormido
  /// y trabajando—, respira hondo con ondas lentas que le recorren la esfera de
  /// polo a polo, y el horizonte es un péndulo que va y viene en vez del riel
  /// que cruza de trabajando. Lo que se ve es un orbe que está en algo, no uno
  /// que está produciendo.
  ponder,

  /// Hablando: late con la voz simulada y emite ondas concéntricas; el
  /// horizonte se convierte en barras verticales.
  speak,
}
