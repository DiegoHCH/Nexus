import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/observador/domain/entities/la_terminal.dart';
import 'package:nexus/features/observador/domain/usecases/lo_que_cuenta_la_terminal.dart';

/// Lo que se sabe de la terminal, evento a evento.
///
/// Lo que llega es JSON de un mod que puede ser de otra versión: lo que no se
/// entiende se ignora, y una sesión que se cierra de golpe no se queda para
/// siempre.
void main() {
  final las9 = DateTime(2026, 10, 15, 9);
  Map<String, dynamic> e(
    String tipo, [
    Map<String, dynamic> extra = const {},
  ]) => {
    'tipo': tipo,
    'sesion': 's1',
    'carpeta': '/Users/a/front-mobile-b2c',
    ...extra,
  };

  LaTerminal tras(List<Map<String, dynamic>> eventos, {DateTime? ahora}) {
    var t = LaTerminal.nada;
    for (final evento in eventos) {
      t = LoQueCuentaLaTerminal.con(t, evento, ahora: ahora ?? las9);
    }
    return t;
  }

  test('una sesión nace libre, y con su carpeta', () {
    final sesion = tras([e('inicio')]).sesiones.single;
    expect(sesion.nombre, 'front-mobile-b2c');
    expect(sesion.trabajando, isFalse);
  });

  test('un turno la pone a trabajar, y cada herramienta dice qué hace', () {
    final sesion = tras([
      e('inicio'),
      e('turno'),
      e('herramienta', {'herramienta': 'Bash', 'detalle': 'flutter test'}),
    ]).sesiones.single;
    expect(sesion.trabajando, isTrue);
    expect(sesion.herramienta, 'Bash');
    expect(sesion.detalle, 'flutter test');
  });

  test('al acabar queda libre, sin herramienta y con su contexto', () {
    final sesion = tras([
      e('turno'),
      e('herramienta', {'herramienta': 'Bash'}),
      e('fin', {'contexto': 42.6}),
    ]).sesiones.single;
    expect(sesion.trabajando, isFalse);
    expect(sesion.herramienta, isNull);
    expect(sesion.contexto, 43);
  });

  test('al cerrar se va, con sus permisos', () {
    final abierta = tras([e('inicio')]);
    final conPermiso = abierta.copyWith(
      permisos: [
        LoQueCuentaLaTerminal.elPermiso({
          'id': 'p1',
          'sesion': 's1',
        }, ahora: las9)!,
      ],
    );
    final cerrada = LoQueCuentaLaTerminal.con(
      conPermiso,
      e('cierre'),
      ahora: las9,
    );
    expect(cerrada.vacia, isTrue);
  });

  test('lo que no se entiende no cambia nada', () {
    final antes = tras([e('inicio')]);
    expect(
      LoQueCuentaLaTerminal.con(antes, {
        'tipo': 'otra-cosa',
        'sesion': 's1',
      }, ahora: las9),
      same(antes),
    );
    expect(
      LoQueCuentaLaTerminal.con(antes, {'tipo': 'turno'}, ahora: las9),
      same(antes),
    );
    expect(
      LoQueCuentaLaTerminal.elPermiso({'sesion': 's1'}, ahora: las9),
      isNull,
    );
  });

  // 🔴 Una terminal cerrada de golpe no manda `cierre`: sin esto, su sesión
  // se quedaba en la barra para siempre.
  test('una sesión que lleva media hora sin contar nada se da por cerrada', () {
    final t = tras([e('inicio')]);
    expect(
      LoQueCuentaLaTerminal.sinLasCalladas(
        t,
        ahora: las9.add(const Duration(minutes: 29)),
      ).sesiones,
      hasLength(1),
    );
    expect(
      LoQueCuentaLaTerminal.sinLasCalladas(
        t,
        ahora: las9.add(const Duration(minutes: 31)),
      ).vacia,
      isTrue,
    );
  });
}
