import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';

/// Una barra con su nombre, su cifra y, si hace falta, una nota debajo.
///
/// Vive en su propio archivo y **no privada dentro del compositor** para poder
/// probarla dibujada, como `ActivityHeatmap` y `ModelsChart`: el fallo que se
/// coló aquí —el valor empujando la fila 192 px fuera del panel— no lo ve el
/// análisis ni una prueba de reglas, solo una que la pinte en el ancho de
/// verdad.
class Gauge extends StatelessWidget {
  const Gauge({
    super.key,
    required this.label,
    required this.percent,
    this.value,
    this.note,
    this.warnAt = 90,
  });

  final String label;
  final int percent;

  /// Lo que se escribe **debajo del nombre**, en su propia fila. Sin él va el
  /// porcentaje solo, a la derecha del nombre: es lo que basta para una
  /// cuota. Con él, el medidor se apila —ver el comentario de `build`—,
  /// porque lo que llega aquí es largo: las cifras de tokens o un «sin dato».
  final String? value;

  final String? note;
  final int warnAt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pasado = percent >= warnAt;
    final barra = LinearProgressIndicator(
      value: percent / 100,
      minHeight: 3,
      backgroundColor: colors.rule,
      color: pasado ? colors.warn : colors.accent,
    );

    // **Con solo el porcentaje, en una fila**: el nombre a la izquierda y la
    // cifra a la derecha, como la `.medida` del mockup. «Límite de 5 horas ·
    // 48 %» cabe de sobra en 300 px, y apilarlo gastaba una línea por barra
    // para decir lo mismo.
    //
    // La cifra en la letra del instrumento y con cifras tabulares: es lo que
    // se lee primero, y al cambiar de 9 a 10 % no baila. Toma el color de la
    // barra al pasar el umbral, porque una barra ámbar con el número en gris
    // se mira dos veces.
    if (value == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.nota.copyWith(color: colors.ink),
                ),
              ),
              const SizedBox(width: NexusSpacing.s3),
              Text(
                '$percent %',
                style: NexusTypography.control.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontVariations: const [FontVariation('wght', 500)],
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: pasado ? colors.warn : colors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: NexusSpacing.s1),
          barra,
          if (note case final texto?) ...[
            const SizedBox(height: 3),
            Text(
              texto,
              style: NexusTypography.nota.copyWith(
                fontSize: 11.5,
                color: colors.mute,
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // **Cada dato en su fila**: el nombre entero, la cifra debajo, y la
        // barra al final. Compartiendo línea no cabían: en un panel de 300 px
        // con tipografía mono, «Ventana de contexto» y «31,1k / 200,0k (16 %)»
        // se recortaban **los dos** —quedaba «Ventana de con… 31,1k / 200,0k
        // (…»—, y un medidor que no deja leer ni su nombre ni su número no mide
        // nada. Apilarlos cuesta una línea de alto y los enseña completos.
        //
        // Cuándo se renueva sigue debajo del todo, por lo mismo de siempre: es
        // secundario, y apretado arriba ya desbordó una vez cuando el plazo
        // pasó de horas a días («129 h 27 m»).
        Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: NexusTypography.control.copyWith(color: colors.mute),
        ),
        const SizedBox(height: 2),
        // La cifra toma el color de la barra al pasar el umbral: es lo que se
        // lee primero, y una barra ámbar con el número en gris se mira dos
        // veces.
        Text(
          value ?? '$percent %',
          overflow: TextOverflow.ellipsis,
          style: NexusTypography.data.copyWith(
            color: percent >= warnAt ? colors.warn : colors.faint,
          ),
        ),
        const SizedBox(height: 4),
        barra,
        if (note case final texto?) ...[
          const SizedBox(height: 3),
          Text(
            texto,
            style: NexusTypography.mono.copyWith(color: colors.faint),
          ),
        ],
      ],
    );
  }
}
