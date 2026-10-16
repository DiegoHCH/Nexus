// El tablero de agentes. Ver `ElTableroDeAgentes`.

mixin TableroStrings {
  String get tableroTitulo;
  String get tableroExplica;
  String tableroTrabajando(int cuantas);
  String tableroPidenPermiso(int cuantos);
  String get tableroNada;
  String get tableroTerminal;
  String get tableroIrAEla;
}

mixin TableroStringsEs implements TableroStrings {
  @override
  String get tableroTitulo => 'Agentes';
  @override
  String get tableroExplica =>
      'Tus conversaciones y tus sesiones de la terminal, todas a la vez: cómo '
      'está cada una, en qué paso va y qué permiso espera. Pulsa una '
      'conversación para ir a ella.';
  @override
  String tableroTrabajando(int cuantas) =>
      cuantas == 1 ? '1 trabajando' : '$cuantas trabajando';
  @override
  String tableroPidenPermiso(int cuantos) =>
      cuantos == 1 ? '1 pide permiso' : '$cuantos piden permiso';
  @override
  String get tableroNada => 'No hay ninguna conversación abierta.';
  @override
  String get tableroTerminal => 'Terminal';
  @override
  String get tableroIrAEla => 'Ir a ella';
}

mixin TableroStringsEn implements TableroStrings {
  @override
  String get tableroTitulo => 'Agents';
  @override
  String get tableroExplica =>
      'Your conversations and terminal sessions, all at once: how each one '
      'is doing, which step it is on and what permission it is waiting for. '
      'Click a conversation to go to it.';
  @override
  String tableroTrabajando(int cuantas) => '$cuantas working';
  @override
  String tableroPidenPermiso(int cuantos) =>
      cuantos == 1 ? '1 asks for permission' : '$cuantos ask for permission';
  @override
  String get tableroNada => 'No conversation is open.';
  @override
  String get tableroTerminal => 'Terminal';
  @override
  String get tableroIrAEla => 'Go to it';
}
