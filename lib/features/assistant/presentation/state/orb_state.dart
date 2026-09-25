/// Los cuatro estados del orbe y del horizonte. Cada uno cambia el tipo de
/// movimiento del orbe y el tipo de línea del horizonte, nunca solo el color
/// — es lo que permite distinguir el estado a tres metros.
enum NexusOrbState {
  /// En reposo: brasas que laten despacio, sin malla, y el anillo fino del
  /// oído si está puesto. Pasados unos minutos duerme hondo y se apaga más.
  sleep,

  /// Escuchando: la malla aparece y una esfera de partículas envuelve al orbe
  /// y se ondula con la voz.
  listen,

  /// Trabajando: gira mucho más rápido, encogido dentro del reactor —un anillo
  /// de segmentos que se encienden según avanzan los pasos de Claude—.
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
  /// polo a polo, lo cruzan chispas lentas por dentro y por fuera un reloj da
  /// una vuelta por minuto. Lo que se ve es un orbe que está en algo, no uno
  /// que está produciendo.
  ponder,

  /// Hablando: late con la voz, emite ondas concéntricas y lo rodea un anillo
  /// de barras, del acento al violeta, que suelta ecos en los picos.
  speak,
}
