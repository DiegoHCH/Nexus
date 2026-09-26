import 'package:nexus/core/i18n/nexus_strings.dart';

/// «Hoy», «Ayer» o la fecha escrita, como se dice un día.
///
/// Vive en `core` porque **ya son dos quienes lo dicen**: las cabeceras del
/// historial y la línea de cada documento —«Texto · 12 KB · Hoy · 23:14»—. El
/// mockup pone lo mismo en los dos sitios, y un documento con «25/09/2026» al
/// lado de una conversación con «Hoy» obligaba a traducir de una a otra para
/// saber que eran del mismo rato.
///
/// [ahora] se inyecta en las pruebas; en la app es el reloj.
String elDiaLegible(NexusStrings strings, DateTime cuando, {DateTime? ahora}) {
  final reloj = ahora ?? DateTime.now();
  final hoy = DateTime(reloj.year, reloj.month, reloj.day);
  final dia = DateTime(cuando.year, cuando.month, cuando.day);
  if (dia == hoy) return strings.historialHoy;
  // Restando un día del calendario y no veinticuatro horas: con el cambio de
  // hora, «ayer» a medianoche puede estar a veintitrés o veinticinco.
  if (dia == DateTime(hoy.year, hoy.month, hoy.day - 1)) {
    return strings.historialAyer;
  }
  return strings.historialDia(dia, conElAno: dia.year != reloj.year);
}

/// La hora en dos cifras, «09:05»: se lee en columna, así que ocupa siempre lo
/// mismo.
String laHora(DateTime cuando) =>
    '${cuando.hour.toString().padLeft(2, '0')}:'
    '${cuando.minute.toString().padLeft(2, '0')}';
