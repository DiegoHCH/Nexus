import Cocoa
import WebKit
import FlutterMacOS
import XCTest

@testable import Nexus

/// Cerrar el visor de documentos **mataba la app entera**.
///
/// Dos veces el mismo día, con la misma firma: `EXC_BAD_ACCESS` en
/// `objc_release`, dentro de `-[_NSWindowTransformAnimation dealloc]` — la
/// animación de cierre de la ventana soltando algo que ya estaba liberado.
///
/// Ninguna de las pruebas de Dart podía verlo: el fallo está entero del lado de
/// AppKit, en quién libera la ventana y cuándo.
///
/// Lo que se fija aquí **no es el segfault** —depende de la animación y del
/// momento del run loop, y no se reproduce a voluntad— sino las dos condiciones
/// que lo causaban. Con cualquiera de las dos de vuelta, la app se vuelve a
/// morir al cerrar el visor.
final class VisorDeArtefactosTests: XCTestCase {
  private var carpeta: URL!

  override func setUpWithError() throws {
    carpeta = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("nexus-visor-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: carpeta)
  }

  private func documento() throws -> String {
    let archivo = carpeta.appendingPathComponent("mockup.html")
    try "<html><body>hola</body></html>".write(to: archivo, atomically: true, encoding: .utf8)
    return archivo.path
  }

  /// Una imagen **pequeña** a propósito: 40×40 es el caso que se veía mal.
  private func imagenPequena() throws -> String {
    let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: 40, pixelsHigh: 40,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.red.setFill()
    NSRect(x: 0, y: 0, width: 40, height: 40).fill()
    NSGraphicsContext.restoreGraphicsState()

    let archivo = carpeta.appendingPathComponent("mini.png")
    try rep.representation(using: .png, properties: [:])!.write(to: archivo)
    return archivo.path
  }

  /// Primera mitad: AppKit no debe liberar una ventana que ya tiene dueño.
  ///
  /// Una `NSWindow` creada a mano llega con `isReleasedWhenClosed = true`, y el
  /// `Viewer` la guarda con una referencia fuerte. Al cerrar, la liberaban los
  /// dos.
  func testLaVentanaNoLaLiberaAppKitAlCerrarla() throws {
    let visor = Viewer(path: try documento(), onClose: {})
    defer { visor.window.close() }

    XCTAssertFalse(
      visor.window.isReleasedWhenClosed,
      "el Viewer es el dueño de la ventana; si AppKit la libera además, es un release de más"
    )
  }

  /// Segunda mitad: el `Viewer` no puede morir dentro de `windowWillClose`.
  ///
  /// `onClose` lo saca del diccionario que lo sostiene, y con él se va la
  /// ventana. Hacerlo durante el cierre la destruye mientras AppKit todavía
  /// está usándola.
  func testCerrarNoDestruyeElViewerDuranteElPropioCierre() throws {
    var cerrado = false
    let visor = Viewer(path: try documento()) { cerrado = true }

    visor.windowWillClose(
      Notification(name: NSWindow.willCloseNotification, object: visor.window)
    )

    XCTAssertFalse(
      cerrado,
      "onClose corrió dentro de windowWillClose: eso suelta la ventana mientras AppKit la cierra"
    )

    let siguienteTurno = expectation(description: "onClose, un turno después")
    DispatchQueue.main.async { siguienteTurno.fulfill() }
    wait(for: [siguienteTurno], timeout: 2)

    XCTAssertTrue(cerrado, "pero tiene que correr: si no, la ventana no se olvida y no se reabre")
  }

  // MARK: - Lo que el documento puede hacer, y lo que no

  /// Un documento con un script que se delata: si corre, deja una marca en el
  /// DOM. Se mira el DOM y no una consola porque lo que importa es si el efecto
  /// llegó a pasar.
  private func documentoConScript() throws -> String {
    let archivo = carpeta.appendingPathComponent("con-script.html")
    try """
      <html><body><p id="p">hola</p>
      <script>document.getElementById('p').setAttribute('data-corrio','si')</script>
      </body></html>
      """.write(to: archivo, atomically: true, encoding: .utf8)
    return archivo.path
  }

  /// Espera a que el documento esté parseado y devuelve si el script dejó marca.
  ///
  /// Se espera al `<p>` y no al `didFinish`: cargar y maquetar son dos momentos
  /// distintos, y preguntar en el primero devuelve nulo tanto si el script no
  /// corrió como si el DOM todavía no estaba — que son cosas muy distintas.
  private func corrioElScript(en web: WKWebView, timeout: TimeInterval = 15) throws -> Bool {
    var corrio = false
    var resuelto = false
    let listo = expectation(description: "el documento, ya parseado")

    func mirar() {
      web.evaluateJavaScript(
        """
        (function () {
          var p = document.getElementById('p');
          if (!p) { return null; }
          return p.getAttribute('data-corrio') || 'no';
        })()
        """
      ) { valor, _ in
        if let texto = valor as? String, !resuelto {
          corrio = texto == "si"
          resuelto = true
          listo.fulfill()
          return
        }
        guard !resuelto else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: mirar)
      }
    }
    mirar()

    wait(for: [listo], timeout: timeout)
    return corrio
  }

  /// Espera hasta que el script deje su marca. Devuelve si llegó a dejarla.
  private func esperaAQueCorra(en web: WKWebView, timeout: TimeInterval = 10) -> Bool {
    let limite = Date().addingTimeInterval(timeout)
    var corrio = false
    var resuelto = false
    let listo = expectation(description: "el script, ya corrido")

    func mirar() {
      web.evaluateJavaScript(
        """
        (function () {
          var p = document.getElementById('p');
          return p ? (p.getAttribute('data-corrio') || 'no') : null;
        })()
        """
      ) { valor, _ in
        guard !resuelto else { return }
        if let texto = valor as? String, texto == "si" {
          corrio = true
          resuelto = true
          listo.fulfill()
          return
        }
        if Date() > limite {
          resuelto = true
          listo.fulfill()
          return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: mirar)
      }
    }
    mirar()

    wait(for: [listo], timeout: timeout + 5)
    return corrio
  }

  /// El HTML lo escribe Claude, y lo que Claude escribe puede venir influido por
  /// lo que leyó en un repositorio. Con lectura de toda la carpeta —que hace
  /// falta para el `assets/` de al lado— un script podía leer al vecino y
  /// mandarlo fuera.
  ///
  /// 🔴 Desde el 28 sep nace **encendido**, a petición de quien mira —casi todo
  /// lo que se abre es un mockup que necesita sus scripts—, y la casilla sigue
  /// apagándolo. Las páginas de Nexus no llevan scripts y no cambian.
  func testElVisorNaceConScriptsYRedYLasDeNexusNo() throws {
    let visor = Viewer(path: try documento(), onClose: {})
    defer { visor.window.close() }
    XCTAssertTrue(visor.permitido, "un documento de Claude nace con scripts y red")

    let propia = Viewer(path: try documento(), propia: true, onClose: {})
    defer { propia.window.close() }
    XCTAssertFalse(propia.permitido, "una página de Nexus no tiene nada que permitir")
  }

  /// El interruptor tiene que **verse**, o el apagado es una amputación: un
  /// mockup con su gráfica dejaría de funcionar y no habría forma de arreglarlo
  /// desde la ventana.
  func testLaCasillaEstaEnLaBarraDeTitulo() throws {
    let visor = Viewer(path: try documento(), onClose: {})
    defer { visor.window.close() }

    XCTAssertEqual(
      visor.window.titlebarAccessoryViewControllers.count, 1,
      "sin la casilla, apagar los scripts no se puede deshacer desde la ventana"
    )
  }

  /// Como en el mockup: el interruptor a la derecha del título, diciendo su
  /// estado con palabra, y el porqué al pie del documento.
  func testElInterruptorDiceSuEstadoYElPorqueVaAlPie() throws {
    let visor = Viewer(path: try documento(), onClose: {})
    defer { visor.window.close() }

    let accesorio = try XCTUnwrap(visor.window.titlebarAccessoryViewControllers.first)
    XCTAssertEqual(accesorio.layoutAttribute, .trailing)
    let boton = try XCTUnwrap(accesorio.view.subviews.compactMap { $0 as? NSButton }.first)
    XCTAssertTrue(boton.attributedTitle.string.contains(NexusArtifacts.etiquetaEncendido.uppercased()))

    visor.permitir(false)
    XCTAssertTrue(boton.attributedTitle.string.contains(NexusArtifacts.etiquetaApagado.uppercased()))

    let pie = visor.window.contentView?.subviews.first {
      $0.identifier == NSUserInterfaceItemIdentifier("pie")
    }
    XCTAssertEqual((pie as? NSTextField)?.stringValue, NexusArtifacts.ayudaPermiso)
  }

  /// Con la casilla apagada, el script no corre: lo que nace encendido se
  /// puede apagar de verdad.
  func testElScriptDelDocumentoNoCorre() throws {
    let visor = Viewer(path: try documentoConScript(), onClose: {})
    defer { visor.window.close() }
    visor.permitir(false)

    let web = visor.web

    XCTAssertFalse(
      try corrioElScript(en: web),
      "el script del documento no puede ejecutarse sin que nadie lo permita"
    )
  }

  /// Y esto es lo que hace que lo anterior no sea una amputación: el mockup que
  /// necesita su gráfica se puede encender.
  func testConElPermisoDadoSiCorre() throws {
    let visor = Viewer(path: try documentoConScript(), onClose: {})
    defer { visor.window.close() }

    let web = visor.web
    // Nace encendido: corre sin tocar nada.
    XCTAssertTrue(esperaAQueCorra(en: web), "un documento recién abierto ya corre sus scripts")

    // Y apagado y vuelto a encender, corre otra vez. Sin mirar entre medias:
    // con el CI cargado, preguntar durante la recarga del apagado choca con
    // ella (se vio agotando los 15 s).
    visor.permitir(false)
    visor.permitir(true)

    // Se **espera** a que corra en vez de mirar una vez: marcar la casilla
    // recarga, y recargar es asíncrono. Preguntar en el instante siguiente ve
    // todavía el DOM de antes y diría que no corre nunca.
    XCTAssertTrue(
      esperaAQueCorra(en: web),
      "marcada la casilla, el documento vuelve a ser un documento normal"
    )
  }

  /// 🔴 **Escribir encima, en el sitio, recarga la ventana** (28 sep): Claude
  /// edita así, y la carpeta no avisa porque sus entradas no cambian. Mismo
  /// inodo, contenido nuevo: la ventana tiene que enseñarlo sin cerrarla.
  func testEscribirEncimaDelArchivoLoRecarga() throws {
    let ruta = try documento()
    let visor = Viewer(path: ruta, onClose: {})
    defer { visor.window.close() }
    XCTAssertTrue(esperaAlTexto("hola", en: visor.web), "primero enseña lo de antes")

    let archivo = try XCTUnwrap(FileHandle(forWritingAtPath: ruta))
    try archivo.truncate(atOffset: 0)
    try archivo.write(contentsOf: Data("<html><body>adios</body></html>".utf8))
    try archivo.close()

    XCTAssertTrue(
      esperaAlTexto("adios", en: visor.web),
      "escrito encima del mismo archivo, la ventana tiene que enseñar lo nuevo"
    )
  }

  /// Y guardar con un temporal que se renombra encima, dos veces seguidas: la
  /// segunda también tiene que llegar, con el vigía puesto sobre el inodo nuevo.
  func testGuardarConRenombreRecargaUnaYOtraVez() throws {
    let ruta = try documento()
    let visor = Viewer(path: ruta, onClose: {})
    defer { visor.window.close() }
    XCTAssertTrue(esperaAlTexto("hola", en: visor.web))

    try "<html><body>uno</body></html>".write(toFile: ruta, atomically: true, encoding: .utf8)
    XCTAssertTrue(esperaAlTexto("uno", en: visor.web))
    try "<html><body>dos</body></html>".write(toFile: ruta, atomically: true, encoding: .utf8)
    XCTAssertTrue(esperaAlTexto("dos", en: visor.web))
  }

  /// Espera a que el cuerpo del documento diga [texto].
  private func esperaAlTexto(_ texto: String, en web: WKWebView, timeout: TimeInterval = 10) -> Bool {
    let limite = Date().addingTimeInterval(timeout)
    var visto = false
    while Date() < limite && !visto {
      let vuelta = expectation(description: "una mirada al documento")
      web.evaluateJavaScript("document.body ? document.body.innerText : ''") { valor, _ in
        visto = (valor as? String)?.contains(texto) == true
        vuelta.fulfill()
      }
      wait(for: [vuelta], timeout: 2)
      if !visto { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
    }
    return visto
  }

  /// La app sigue pudiendo preguntarle cosas a la página aunque la página no
  /// ejecute las suyas. De eso dependen el reencuadre de las imágenes y el
  /// scroll que se devuelve al recargar: si esto dejara de ser verdad, las dos
  /// cosas se romperían en silencio.
  func testLaAppSiPuedeEjecutarLoSuyo() throws {
    let visor = Viewer(path: try documentoConScript(), onClose: {})
    defer { visor.window.close() }

    let web = visor.web
    _ = try corrioElScript(en: web)

    let respondio = expectation(description: "el webview contesta a la app")
    var texto: String?
    web.evaluateJavaScript("document.getElementById('p').textContent") { valor, _ in
      texto = valor as? String
      respondio.fulfill()
    }
    wait(for: [respondio], timeout: 10)

    XCTAssertEqual(texto, "hola")
  }

  // MARK: - El bloqueo de red

  /// Que la lista de bloqueo **se compile**. Es el fallo realista: un JSON mal
  /// escrito no rompe nada al compilar el proyecto y deja el visor sin bloqueo.
  func testLaListaDeBloqueoCompila() throws {
    guard let almacen = WKContentRuleListStore.default() else {
      return XCTFail("sin almacén de reglas no hay bloqueo que poner")
    }
    let compilada = expectation(description: "la lista, compilada")
    var lista: WKContentRuleList?
    var fallo: Error?
    almacen.compileContentRuleList(
      forIdentifier: "\(Viewer.reglaId)-prueba", encodedContentRuleList: Viewer.sinRed
    ) { resultado, error in
      lista = resultado
      fallo = error
      compilada.fulfill()
    }
    wait(for: [compilada], timeout: 15)

    XCTAssertNil(fallo, "la lista no compiló: \(fallo?.localizedDescription ?? "")")
    XCTAssertNotNil(lista)
  }

  /// Y que las listas **surtan efecto en este visor**, que es la duda de verdad:
  /// un bloqueo instalado que el motor ignora se ve exactamente igual que uno
  /// que funciona.
  ///
  /// Se comprueba al revés, bloqueando `file:` —lo único que hay en una prueba
  /// sin red— y viendo que entonces el documento no llega a pintarse. Con la
  /// lista de verdad, que deja pasar `file:`, sí se pinta: eso lo dicen las
  /// otras pruebas de este archivo.
  func testUnaListaDeBloqueoSurteEfectoEnElVisor() throws {
    guard let almacen = WKContentRuleListStore.default() else {
      return XCTFail("sin almacén de reglas no hay bloqueo que poner")
    }
    let compilada = expectation(description: "la lista, compilada")
    var lista: WKContentRuleList?
    almacen.compileContentRuleList(
      forIdentifier: "nexus-prueba-bloquea-todo",
      encodedContentRuleList: #"[{"trigger": {"url-filter": ".*"}, "action": {"type": "block"}}]"#
    ) { resultado, _ in
      lista = resultado
      compilada.fulfill()
    }
    wait(for: [compilada], timeout: 15)
    guard let lista else { return XCTFail("no compiló la lista de la prueba") }

    let web = WKWebView()
    web.configuration.userContentController.add(lista)
    let archivo = URL(fileURLWithPath: try documentoConScript())
    web.loadFileURL(archivo, allowingReadAccessTo: archivo.deletingLastPathComponent())

    // Se le da tiempo de sobra a cargar y luego se mira: con todo bloqueado, el
    // documento no llega al DOM.
    let espera = expectation(description: "tiempo para que cargara, si pudiera")
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { espera.fulfill() }
    wait(for: [espera], timeout: 5)

    let mirado = expectation(description: "qué hay en el DOM")
    var hayParrafo = true
    web.evaluateJavaScript("document.getElementById('p') !== null") { valor, _ in
      hayParrafo = (valor as? Bool) ?? false
      mirado.fulfill()
    }
    wait(for: [mirado], timeout: 10)

    XCTAssertFalse(
      hayParrafo,
      "si una lista que bloquea todo deja pasar el documento, el bloqueo no lo aplica nadie"
    )
  }

  // MARK: - Cómo se ve la imagen dentro de la ventana

  func testSoloLasImagenesSeReencuadran() {
    for imagen in ["captura.png", "foto.JPG", "animado.gif", "moderna.heic"] {
      XCTAssertTrue(Viewer.isImage("/tmp/\(imagen)"), "\(imagen) la abre WebKit como documento de imagen")
    }
    for otro in ["informe.html", "manual.pdf", "logo.svg", "notas.md"] {
      XCTAssertFalse(Viewer.isImage("/tmp/\(otro)"), "\(otro) trae su propia maquetación y no se toca")
    }
  }

  /// La queja era esta: una captura pequeña arriba a la izquierda de una
  /// ventana enorme, porque WebKit pinta una imagen suelta a tamaño natural.
  ///
  /// Se mide **lo pintado**, no la hoja de estilos: se espera a que la imagen
  /// esté en el DOM y se le pregunta al propio WebKit cuánto ocupa. Con 40×40
  /// de origen, sin reencuadre son 40 puntos.
  func testUnaImagenPequenaOcupaLaVentanaYNoUnaEsquina() throws {
    let visor = Viewer(path: try imagenPequena(), onClose: {})
    defer { visor.window.close() }

    let web = visor.web

    let medida = try esperarMedidaDeLaImagen(en: web)
    XCTAssertGreaterThan(
      medida.width, 900,
      "una imagen de 40 px de ancho tiene que llenar la ventana, no quedarse en su tamaño"
    )
    XCTAssertGreaterThan(medida.height, 600, "y a lo alto igual")
  }

  /// Pregunta al DOM cada 100 ms hasta que la imagen tenga un tamaño **estable**.
  ///
  /// No vale un `didFinish` seco: la carga del archivo y la maquetación son dos
  /// momentos distintos, y medir en el primero da cero.
  ///
  /// 🔴 **Y tampoco vale la primera medida no nula, que es lo que hacía.**
  /// «Tiene tamaño» no es «tiene su tamaño final»: con la máquina ocupada, la
  /// primera lectura pillaba una maquetación intermedia —la imagen a sus 40 px,
  /// antes de que el CSS la escale— y la prueba fallaba en 1,4 s, muy por debajo
  /// del plazo. O sea que no expiraba: medía pronto y comparaba mal.
  ///
  /// El criterio es la estabilidad y no un umbral, a propósito: un umbral aquí
  /// metería la aserción dentro de la espera, y entonces la prueba se estaría
  /// esperando a sí misma.
  private func esperarMedidaDeLaImagen(
    en web: WKWebView, timeout: TimeInterval = 15
  ) throws -> CGSize {
    var medida = CGSize.zero
    var anterior = CGSize.zero
    var resuelto = false
    let pintada = expectation(description: "la imagen, ya maquetada y quieta")

    func mirar() {
      web.evaluateJavaScript(
        """
        (function () {
          var i = document.images[0];
          if (!i) { return null; }
          var r = i.getBoundingClientRect();
          return [r.width, r.height];
        })()
        """
      ) { valor, _ in
        guard !resuelto else { return }
        if let par = valor as? [Double], par[0] > 0 {
          let ahora = CGSize(width: par[0], height: par[1])
          // Dos lecturas seguidas iguales: la maquetación dejó de moverse.
          if ahora == anterior {
            medida = ahora
            resuelto = true
            pintada.fulfill()
            return
          }
          anterior = ahora
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: mirar)
      }
    }
    mirar()

    wait(for: [pintada], timeout: timeout)
    return medida
  }

  /// El color de fondo en CSS se deriva del `NSColor`, así que no pueden
  /// separarse. Esta prueba es lo que sostiene esa afirmación.
  func testElFondoDelVisorEsElVoidDelTemaElegido() {
    let antes = NexusAppearance.isDark
    defer { NexusAppearance.apply(dark: antes) }

    NexusAppearance.apply(dark: true)
    XCTAssertEqual(NexusAppearance.voidCSS, "#04070D")

    NexusAppearance.apply(dark: false)
    XCTAssertEqual(NexusAppearance.voidCSS, "#E9EEF5")
  }
}

/// El icono de la barra de estado: que **diga en qué anda**, que era el punto.
///
/// Presencia sola no aportaba nada que no dijera el Dock. Lo que hacía falta es
/// distinguir «sigue trabajando» sin ir a buscar la ventana, porque un encargo
/// de Claude dura minutos.
final class BarraDeEstadoTests: XCTestCase {
  func testLosEstadosDelOrbeSeTraducenATresAspectos() {
    // Cuatro estados lógicos, tres aspectos: a 16 px no caben cuatro
    // diferencias legibles, y «hablando» y «escuchando» son lo mismo para quien
    // mira de reojo — los dos son «está contigo».
    XCTAssertEqual(NexusStatusItem.Presence.from("sleep"), .asleep)
    XCTAssertEqual(NexusStatusItem.Presence.from("listen"), .active)
    XCTAssertEqual(NexusStatusItem.Presence.from("speak"), .active)
    XCTAssertEqual(NexusStatusItem.Presence.from("think"), .working)
  }

  func testLoQueNoSeConoceSeDaPorDormido() {
    // El nombre viaja como cadena desde Dart. Si algún día se añade un estado
    // allí y no aquí, lo seguro es enseñar el icono en reposo y no romper.
    XCTAssertEqual(NexusStatusItem.Presence.from("loQueSea"), .asleep)
    XCTAssertEqual(NexusStatusItem.Presence.from(""), .asleep)
  }

  func testDormidoEsPlantillaYActivoNo() throws {
    // Dormido lo tiñe el sistema, así que se ve en barra clara y oscura. Activo
    // **no** puede ser plantilla: ahí el color es la información, y teñirlo
    // dejaría «escuchando» idéntico a «dormido».
    let dormido = try imagen(.asleep)
    let activo = try imagen(.active)

    XCTAssertTrue(dormido.isTemplate)
    XCTAssertFalse(activo.isTemplate)
  }

  func testCadaAspectoSeVeDistinto() throws {
    // Que existan tres estados no sirve de nada si pintan lo mismo. Se comparan
    // los mapas de bits: trabajando lleva el punto central.
    let activo = try datos(.active)
    let trabajando = try datos(.working)
    let dormido = try datos(.asleep)

    XCTAssertNotEqual(activo, trabajando, "«trabajando» se pinta igual que «activo»")
    XCTAssertNotEqual(activo, dormido)
  }

  private func imagen(_ p: NexusStatusItem.Presence) throws -> NSImage {
    NexusStatusItem.show(p)
    return try XCTUnwrap(NexusStatusItem.currentImage, "no hay icono en la barra")
  }

  private func datos(_ p: NexusStatusItem.Presence) throws -> Data {
    let img = try imagen(p)
    let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: 16, pixelsHigh: 16,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16))
    NSGraphicsContext.restoreGraphicsState()
    return try XCTUnwrap(rep.representation(using: .png, properties: [:]))
  }
}

/// El menú de la barra: existe, y con los rótulos que le manda la app.
extension BarraDeEstadoTests {
  func testSinMenuElIconoParecíaRoto() throws {
    // Lo reportado: pulsarlo resaltaba el botón y no pasaba nada, así que
    // quedaba un recuadro oscuro encendido sin explicación. Con menú, ese
    // resaltado pasa a significar algo — está abierto.
    NexusStatusItem.show(.asleep)
    NexusStatusItem.setMenuForTesting([
      "talk": "Hablar con Nexus",
      "show": "Abrir la ventana",
      "settings": "Ajustes",
      "quit": "Salir de Nexus",
    ])

    let menu = try XCTUnwrap(NexusStatusItem.currentMenu, "el icono no tiene menú")
    let titulos = menu.items.map(\.title).filter { !$0.isEmpty }
    XCTAssertEqual(
      titulos,
      ["Hablar con Nexus", "Abrir la ventana", "Ajustes", "Salir de Nexus"]
    )
  }

  func testUnRotuloVacioNoDejaUnaFilaMuda() throws {
    // Los rótulos vienen de Dart. Si alguno llegara vacío —un texto sin traducir,
    // un canal a medias— una fila en blanco es peor que no tener la fila.
    NexusStatusItem.setMenuForTesting(["talk": "Hablar", "show": "", "quit": "Salir"])

    let menu = try XCTUnwrap(NexusStatusItem.currentMenu)
    XCTAssertEqual(menu.items.map(\.title).filter { !$0.isEmpty }, ["Hablar", "Salir"])
  }

  func testElMenuVaEnElOrdenDelMockupYConSusAtajos() throws {
    // Hablar primero, que es para lo que existe el menú; la versión nueva en su
    // propio grupo, antes de salir; y cada entrada con su atajo al lado.
    NexusStatusItem.setMenuForTesting([
      "talk": "Hablar con Nexus",
      "show": "Abrir la ventana",
      "settings": "Ajustes…",
      "update": "Hay una versión nueva: 1.26.0",
      "quit": "Salir de Nexus",
    ])

    let menu = try XCTUnwrap(NexusStatusItem.currentMenu)
    XCTAssertEqual(
      menu.items.map { $0.isSeparatorItem ? "—" : $0.title },
      [
        "Hablar con Nexus", "Abrir la ventana", "Ajustes…", "—",
        "Hay una versión nueva: 1.26.0", "—", "Salir de Nexus",
      ]
    )
    let hablar = menu.items[0]
    XCTAssertEqual(hablar.keyEquivalent, " ")
    XCTAssertEqual(hablar.keyEquivalentModifierMask, [.option])
    XCTAssertEqual(menu.items[2].keyEquivalent, ",")
    XCTAssertEqual(menu.items.last?.keyEquivalent, "q")
  }
}

/// **La botonera en su ventana aparte.** Lo que se fija es lo que no se ve
/// hasta que pasa: que un sitio guardado en un monitor que ya no está no deje
/// la barra perdida fuera de la pantalla —una ventana sin marco fuera de la
/// pantalla no tiene por dónde agarrarse—, y que cada juego de pantallas
/// recuerde el suyo.
final class BotoneraDeFueraTests: XCTestCase {
  /// Un portátil y, a su derecha, un monitor más alto. Marcos visibles.
  private let portatil = NSRect(x: 0, y: 0, width: 1512, height: 944)
  private let monitor = NSRect(x: 1512, y: -200, width: 2560, height: 1415)

  private func marco(x: CGFloat, y: CGFloat, alto: CGFloat = 120) -> NSRect {
    NSRect(x: x, y: y, width: NexusBotonera.ancho, height: alto)
  }

  private func entera(_ marco: NSRect, en pantalla: NSRect) -> Bool {
    marco.minX >= pantalla.minX && marco.maxX <= pantalla.maxX
      && marco.minY >= pantalla.minY && marco.maxY <= pantalla.maxY
  }

  func testNaceAbajoALaDerechaYSinTaparElOrbe() {
    let nace = NexusBotonera.dondeNace(en: portatil, alto: 120)
    XCTAssertEqual(nace.maxX, portatil.maxX - NexusBotonera.margen)
    XCTAssertEqual(nace.width, NexusBotonera.ancho)
    let orbe = NexusOrbeFlotante.dondeVa(en: portatil)
    XCTAssertFalse(nace.intersects(orbe), "el orbe sale a esa esquina: taparlo es esconder a quien te atiende")
    XCTAssertTrue(entera(nace, en: portatil))
  }

  /// Se guardó con el monitor enchufado y se abre en el portátil solo.
  func testUnSitioEnUnMonitorQueYaNoEstaVuelveALaPrincipal() {
    let enElMonitor = marco(x: 3000, y: 600)
    let ahora = NexusBotonera.dentro(enElMonitor, de: [portatil])
    XCTAssertTrue(entera(ahora, en: portatil), "fuera de la pantalla no hay asa que agarrar: \(ahora)")
  }

  func testMedioFueraSeTraeEntera() {
    // Casi entera en el portátil, asomando por abajo y rozando el monitor.
    let asomando = marco(x: portatil.maxX - 330, y: -60)
    let ahora = NexusBotonera.dentro(asomando, de: [portatil, monitor])
    XCTAssertTrue(entera(ahora, en: portatil))
    XCTAssertEqual(ahora.size, asomando.size, "se mueve, no se encoge")
  }

  /// Con dos pantallas va a la que más la tiene, no siempre a la principal:
  /// dejarla en el monitor es una decisión, y rozar el borde no la deshace.
  func testSeQuedaEnLaPantallaDondeMasAsoma() {
    let casiEnElMonitor = marco(x: monitor.minX - 40, y: 300)
    let ahora = NexusBotonera.dentro(casiEnElMonitor, de: [portatil, monitor])
    XCTAssertTrue(entera(ahora, en: monitor))
    XCTAssertEqual(ahora.minX, monitor.minX)
  }

  /// Muchas corridas en una pantalla baja: se ve el asa, que es por donde se
  /// agarra, y lo que sobra cae por abajo.
  func testSiNoCabeDeAltoMandaElAsa() {
    let bajita = NSRect(x: 0, y: 0, width: 1280, height: 300)
    let ahora = NexusBotonera.dentro(marco(x: 100, y: 50, alto: 420), de: [bajita])
    XCTAssertEqual(ahora.maxY, bajita.maxY)
  }

  /// Como dentro de Nexus: una corrida nueva la hace crecer hacia arriba y no
  /// la asoma por debajo de donde la dejaste.
  func testCreceHaciaArriba() {
    let antes = marco(x: 200, y: 100, alto: 120)
    let despues = NexusBotonera.conAlto(antes, alto: 230)
    XCTAssertEqual(despues.minY, antes.minY)
    XCTAssertEqual(despues.minX, antes.minX)
    XCTAssertEqual(despues.height, 230)
  }

  /// Arrastrar sigue al ratón **de la pantalla**: la ventana se mueve lo que se
  /// movió el ratón, esté donde esté la ventana en cada paso.
  func testArrastrarSigueAlRatonDeLaPantalla() {
    let origen = NSPoint(x: 500, y: 300)
    let movida = NexusBotonera.arrastrada(
      origen: origen, desde: NSPoint(x: 700, y: 400), hasta: NSPoint(x: 650, y: 520))
    XCTAssertEqual(movida, NSPoint(x: 450, y: 420))
  }

  /// La de la oficina no es la del portátil: cada juego de pantallas guarda la
  /// suya, y uno nuevo no pisa el de antes.
  func testCadaJuegoDePantallasRecuerdaSuSitio() throws {
    let nombre = "nexus-botonera-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: nombre))
    defer { defaults.removePersistentDomain(forName: nombre) }

    let solo = NexusBotonera.firma(de: [portatil])
    let conMonitor = NexusBotonera.firma(de: [portatil, monitor])
    XCTAssertNotEqual(solo, conMonitor)
    XCTAssertNil(NexusBotonera.guardado(firma: solo, en: defaults))

    NexusBotonera.guardar(NSPoint(x: 10, y: 20), firma: solo, en: defaults)
    NexusBotonera.guardar(NSPoint(x: 2000, y: 500), firma: conMonitor, en: defaults)

    XCTAssertEqual(NexusBotonera.guardado(firma: solo, en: defaults), NSPoint(x: 10, y: 20))
    XCTAssertEqual(
      NexusBotonera.guardado(firma: conMonitor, en: defaults), NSPoint(x: 2000, y: 500))
  }

  /// El orden en que el sistema enumere las pantallas no es otro escritorio.
  func testLaFirmaNoDependeDelOrden() {
    XCTAssertEqual(
      NexusBotonera.firma(de: [portatil, monitor]),
      NexusBotonera.firma(de: [monitor, portatil]))
  }

  /// «Mostrar la botonera» solo cuando llega su rótulo, que Dart manda solo
  /// con la botonera escondida. Va junto a «Abrir la ventana»: las dos traen
  /// algo de Nexus al frente.
  func testElMenuTraeLaBotoneraSoloSiEstaEscondida() throws {
    NexusStatusItem.setMenuForTesting([
      "talk": "Hablar con Nexus",
      "show": "Abrir la ventana",
      "runBar": "Mostrar la botonera",
      "settings": "Ajustes…",
      "quit": "Salir de Nexus",
    ])
    let conEscondida = try XCTUnwrap(NexusStatusItem.currentMenu)
    XCTAssertEqual(
      conEscondida.items.map { $0.isSeparatorItem ? "—" : $0.title },
      ["Hablar con Nexus", "Abrir la ventana", "Mostrar la botonera", "Ajustes…", "—", "Salir de Nexus"]
    )

    NexusStatusItem.setMenuForTesting([
      "talk": "Hablar con Nexus",
      "show": "Abrir la ventana",
      "settings": "Ajustes…",
      "quit": "Salir de Nexus",
    ])
    let sin = try XCTUnwrap(NexusStatusItem.currentMenu)
    XCTAssertFalse(sin.items.contains { $0.title == "Mostrar la botonera" })
  }
}

/// **El espejo pegado a la botonera.** Pedido: «que sean pegadas pero que al
/// moverla se muevan juntas». Lo que se fija es la geometría —dónde va el
/// espejo, cuándo se pone encima, cómo vuelve la barra si se mueve el espejo—
/// y lo que evita el bucle: sin reconocer el eco, mover uno movía al otro y el
/// otro al primero.
final class EspejoPegadoTests: XCTestCase {
  private let pantalla = NSRect(x: 0, y: 0, width: 1512, height: 944)
  /// Un teléfono en vertical, 9:19,5.
  private let telefono = NSSize(width: 360, height: 780)

  private func barra(y: CGFloat, alto: CGFloat = 120) -> NSRect {
    NSRect(x: 600, y: y, width: NexusBotonera.ancho, height: alto)
  }

  func testAlPegarseTomaElAnchoDeLaBarraConSuProporcion() {
    let tamano = NexusEspejoPegado.tamanoAlPegar(telefono, ancho: NexusBotonera.ancho)
    XCTAssertEqual(tamano.width, NexusBotonera.ancho)
    XCTAssertEqual(tamano.height / tamano.width, telefono.height / telefono.width, accuracy: 0.01)
  }

  /// Debajo, pegado —sin aire, que dos ventanas con hueco se leen como dos— y
  /// centrado.
  func testVaDebajoPegadoYCentrado() {
    let arriba = barra(y: 800)
    let (marco, lado) = NexusEspejoPegado.dondeVaElEspejo(
      barra: arriba, espejo: NSSize(width: 430, height: 600), pantalla: pantalla)
    XCTAssertEqual(lado, .abajo)
    XCTAssertEqual(marco.maxY, arriba.minY, "sin hueco entre las dos")
    XCTAssertEqual(marco.midX, arriba.midX)
    XCTAssertEqual(marco.size, NSSize(width: 430, height: 600))
  }

  /// Con la barra abajo del todo no cabe debajo: se pone encima.
  func testSinSitioDebajoSePoneEncima() {
    let abajo = barra(y: 40)
    let (marco, lado) = NexusEspejoPegado.dondeVaElEspejo(
      barra: abajo, espejo: NSSize(width: 430, height: 600), pantalla: pantalla)
    XCTAssertEqual(lado, .arriba)
    XCTAssertEqual(marco.minY, abajo.maxY)
    XCTAssertLessThanOrEqual(marco.maxY, pantalla.maxY)
  }

  /// Sin sitio en ningún lado: en el que más haya, encogido con su proporción.
  func testSinSitioEnNingunLadoSeEncogeConSuProporcion() {
    let enMedio = barra(y: 400)
    let alto = NSSize(width: 430, height: 931)
    let (marco, lado) = NexusEspejoPegado.dondeVaElEspejo(
      barra: enMedio, espejo: alto, pantalla: pantalla)
    XCTAssertEqual(lado, .arriba, "arriba quedan 424 y abajo 400")
    XCTAssertEqual(marco.minY, enMedio.maxY)
    XCTAssertEqual(marco.maxY, pantalla.maxY)
    XCTAssertEqual(marco.height / marco.width, alto.height / alto.width, accuracy: 0.01)
  }

  func testNoSeSalePorLosLados() {
    let alBorde = NSRect(x: 0, y: 800, width: NexusBotonera.ancho, height: 120)
    let (marco, _) = NexusEspejoPegado.dondeVaElEspejo(
      barra: alBorde, espejo: NSSize(width: 600, height: 500), pantalla: pantalla)
    XCTAssertGreaterThanOrEqual(marco.minX, pantalla.minX)
  }

  /// Si quien se mueve es el espejo, la barra vuelve a su sitio encima de él
  /// —o debajo, si el espejo iba encima—.
  func testLaBarraSigueAlEspejo() {
    let espejo = NSRect(x: 100, y: 100, width: 430, height: 600)
    let encima = NexusEspejoPegado.dondeVaLaBarra(
      espejo: espejo, lado: .abajo, barra: NSSize(width: 430, height: 120))
    XCTAssertEqual(encima, NSPoint(x: 100, y: 700))
    let debajo = NexusEspejoPegado.dondeVaLaBarra(
      espejo: espejo, lado: .arriba, barra: NSSize(width: 430, height: 120))
    XCTAssertEqual(debajo, NSPoint(x: 100, y: -20))
  }

  /// 🔴 Se queda en su escritorio (28 sep): con `.canJoinAllSpaces` salía
  /// encima de cualquier app al cambiar de pantalla. Junto a una app a pantalla
  /// completa sí puede estar, que es donde va el espejo.
  func testLaBotoneraSeQuedaEnSuEscritorio() {
    XCTAssertFalse(NexusBotonera.enLosEscritorios.contains(.canJoinAllSpaces))
    XCTAssertFalse(NexusBotonera.enLosEscritorios.contains(.moveToActiveSpace))
    XCTAssertTrue(NexusBotonera.enLosEscritorios.contains(.fullScreenAuxiliary))
    // Escrito y no por defecto: en nivel flotante, el de fábrica es `.transient`,
    // que la lleva a cualquier escritorio al que pases.
    XCTAssertTrue(NexusBotonera.enLosEscritorios.contains(.managed))
    XCTAssertFalse(NexusBotonera.enLosEscritorios.contains(.transient))
  }

  /// 🔴 Con el espejo a pantalla completa, «encima del espejo» es fuera de la
  /// pantalla: la barra se queda dentro, montada sobre su borde. Era lo que
  /// tumbaba la app el 28 sep —el motor de la barra sin pantalla—.
  func testConElEspejoAPantallaCompletaLaBarraNoSaleDeLaPantalla() {
    let completa = NSRect(x: 0, y: 0, width: 1512, height: 982)
    let tamano = NSSize(width: 430, height: 120)
    let pegada = NexusEspejoPegado.dondeVaLaBarra(espejo: completa, lado: .abajo, barra: tamano)
    XCTAssertGreaterThanOrEqual(pegada.y, completa.maxY, "sin ajustar, se sale por arriba")

    let origen = NexusBotonera.pegadaAlEspejo(pegada, tamano: tamano, de: [completa])
    let marco = NSRect(origin: origen, size: tamano)
    XCTAssertTrue(completa.contains(marco), "la barra tiene que quedar dentro: \(marco)")
    XCTAssertEqual(origen.x, pegada.x, "y sin moverse de lado: sigue centrada sobre el espejo")
  }

  /// Si cabe donde toca, no se toca: pegada al espejo, como antes.
  func testConSitioLaBarraSigueJustoEncimaDelEspejo() {
    let pantalla = NSRect(x: 0, y: 0, width: 1512, height: 982)
    let espejo = NSRect(x: 100, y: 100, width: 430, height: 600)
    let tamano = NSSize(width: 430, height: 120)
    let pegada = NexusEspejoPegado.dondeVaLaBarra(espejo: espejo, lado: .abajo, barra: tamano)
    XCTAssertEqual(NexusBotonera.pegadaAlEspejo(pegada, tamano: tamano, de: [pantalla]), pegada)
  }

  /// 🔴 El trinquete que encogía el espejo (28 sep): scrcpy contesta a cada
  /// tamaño con uno algo menor. Recolocar diez veces seguidas —lo que pasa al
  /// arrastrar— tiene que dejarlo del mismo tamaño que la primera, no diez
  /// veces más chico.
  func testRecolocarVariasVecesNoEncogeElEspejo() {
    let barra = NSRect(x: 500, y: 700, width: 430, height: 120)
    let deseado = NSSize(width: 430, height: 930)
    let pantalla = NSRect(x: 0, y: 0, width: 1512, height: 1900)
    // Lo que hace scrcpy: quita la barra de título y guarda la proporción.
    func scrcpy(_ pedido: NSSize) -> NSSize {
      let titulo: CGFloat = 28
      let alto = pedido.height
      return NSSize(width: ((alto - titulo) * 430 / 930).rounded(), height: alto)
    }
    var ajuste: AjusteDelEspejo?
    var tamanos: [NSSize] = []
    for _ in 0..<10 {
      let (pedido, lado) = NexusEspejoPegado.dondeVaElEspejo(
        barra: barra, espejo: deseado, pantalla: pantalla)
      let puesto = NexusEspejoPegado.conLoQueAcepta(pedido, lado: lado, barra: barra, ajuste: ajuste)
      let quedo = puesto.size == pedido.size ? scrcpy(puesto.size) : puesto.size
      if quedo != pedido.size { ajuste = AjusteDelEspejo(pedido: pedido.size, quedo: quedo) }
      tamanos.append(quedo)
    }
    XCTAssertEqual(Set(tamanos.map { "\($0)" }).count, 1, "siempre el mismo: \(tamanos)")
  }

  /// Lo que acepta se usa para colocar, pegado y centrado bajo la barra.
  func testConLoQueAceptaSeCentraYSePega() {
    let barra = NSRect(x: 500, y: 700, width: 430, height: 120)
    let pedido = NSRect(x: 500, y: -230, width: 430, height: 930)
    let ajuste = AjusteDelEspejo(pedido: pedido.size, quedo: NSSize(width: 417, height: 930))
    let puesto = NexusEspejoPegado.conLoQueAcepta(pedido, lado: .abajo, barra: barra, ajuste: ajuste)
    XCTAssertEqual(puesto.size, NSSize(width: 417, height: 930))
    XCTAssertEqual(puesto.maxY, barra.minY, "pegado a la barra")
    XCTAssertEqual(puesto.midX, barra.midX, accuracy: 1, "y centrado")
    // Otro pedido —otro tamaño deseado—: el ajuste de antes no vale.
    let otro = NSRect(x: 500, y: -100, width: 430, height: 800)
    XCTAssertEqual(
      NexusEspejoPegado.conLoQueAcepta(otro, lado: .abajo, barra: barra, ajuste: ajuste), otro)
  }

  /// Ida y vuelta: poner el espejo donde va y volver a poner la barra desde él
  /// deja la barra donde estaba. Si no, arrastrar el espejo la haría saltar.
  func testIdaYVueltaNoMueveLaBarra() {
    let original = barra(y: 800)
    let (marco, lado) = NexusEspejoPegado.dondeVaElEspejo(
      barra: original, espejo: NSSize(width: 430, height: 600), pantalla: pantalla)
    let vuelta = NexusEspejoPegado.dondeVaLaBarra(espejo: marco, lado: lado, barra: original.size)
    XCTAssertEqual(vuelta, original.origin)
  }

  /// 🔴 Lo que avisa el espejo después de moverlo nosotros es eco: con esto
  /// reconocido, mover la barra no vuelve a moverla a ella.
  func testElEcoSeReconoceYUnArrastreNo() {
    let puesto = NSRect(x: 100, y: 100, width: 430, height: 600)
    XCTAssertTrue(NexusEspejoPegado.esEco(esperado: puesto, visto: puesto.offsetBy(dx: 1, dy: -1)))
    XCTAssertFalse(NexusEspejoPegado.esEco(esperado: puesto, visto: puesto.offsetBy(dx: 30, dy: 0)))
    XCTAssertFalse(NexusEspejoPegado.esEco(esperado: nil, visto: puesto))
  }

  /// Accesibilidad cuenta desde arriba; AppKit desde abajo.
  func testLasCoordenadasDeAccesibilidadVanYVuelven() {
    let marco = NSRect(x: 50, y: 100, width: 430, height: 600)
    let punto = NexusEspejoPegado.aAccesibilidad(marco, altoPrincipal: 1117)
    XCTAssertEqual(punto, CGPoint(x: 50, y: 417))
    XCTAssertEqual(
      NexusEspejoPegado.desdeAccesibilidad(posicion: punto, tamano: marco.size, altoPrincipal: 1117),
      marco)
  }

  /// Con dos emuladores del mismo modelo manda el título —el puerto—; sin
  /// título, la que haya; y con varias y ninguna con el título, ninguna.
  func testLaVentanaQueTocaSeEligePorElTitulo() {
    let titulos = ["Android Emulator - Pixel_9:5556", "Android Emulator - Pixel_9:5554"]
    XCTAssertEqual(NexusEspejoPegado.laQueToca(titulos, titulo: ":5554"), 1)
    XCTAssertNil(NexusEspejoPegado.laQueToca(titulos, titulo: ":5560"))
    XCTAssertEqual(NexusEspejoPegado.laQueToca(["iPhone Mirroring"], titulo: nil), 0)
    XCTAssertEqual(NexusEspejoPegado.laQueToca(["POCO"], titulo: "POCO F6"), 0, "una sola: esa")
    XCTAssertNil(NexusEspejoPegado.laQueToca([], titulo: nil))
  }

  func testLoQueSeBuscaLlegaDeDartYReconoceASuApp() {
    let busca = LaVentanaDelEspejo(datos: [
      "ejecutables": ["qemu-system"], "apps": ["com.apple.iphonesimulator"], "titulo": ":5554",
    ])
    XCTAssertEqual(busca.titulo, ":5554")
    XCTAssertTrue(busca.esSuya(bundle: nil, ejecutable: "qemu-system-aarch64"))
    XCTAssertTrue(busca.esSuya(bundle: "com.apple.iphonesimulator", ejecutable: "Simulator"))
    XCTAssertFalse(busca.esSuya(bundle: "com.apple.Safari", ejecutable: "Safari"))
  }
}

/// El tema se pinta en las ventanas de la app, no en las del sistema.
final class AparienciaTests: XCTestCase {
  func testSoloLasVentanasMarcadasSonNuestras() {
    let ventana = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
      styleMask: [.titled, .closable], backing: .buffered, defer: false
    )
    ventana.isReleasedWhenClosed = false
    defer { ventana.close() }

    XCTAssertFalse(NexusAppearance.isOurs(ventana), "sin marca, no es nuestra")
    ventana.identifier = NexusAppearance.ourMark
    XCTAssertTrue(NexusAppearance.isOurs(ventana))
  }

  func testUnaVentanaSinMostrarSigueSiendoNuestra() {
    // Se probó primero con `canBecomeMain` y era un mal criterio: también es
    // falso para una ventana que aún no se ha mostrado, así que al arrancar se
    // habría saltado la principal y el marco se habría quedado sin tema.
    let ventana = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
      styleMask: [.titled], backing: .buffered, defer: false
    )
    ventana.isReleasedWhenClosed = false
    ventana.identifier = NexusAppearance.ourMark
    defer { ventana.close() }

    XCTAssertFalse(ventana.isVisible)
    XCTAssertTrue(NexusAppearance.isOurs(ventana))
  }

  func testLaVentanaDeLaBarraDeEstadoNoLoEs() {
    // Reportado mirando la barra: el icono de Nexus llevaba **un recuadro negro
    // detrás** y los demás no. Era el `--void` de la paleta: `apply` recorría
    // todas las ventanas de `NSApplication.shared.windows`, y la del icono de la
    // barra está en esa lista aunque no sea nuestra.
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 40, height: 20),
      styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false
    )
    defer { panel.close() }
    XCTAssertFalse(
      NexusAppearance.isOurs(panel),
      "una ventana que no puede ser la principal no es de la app: pintarla le pone fondo a algo del sistema"
    )
  }
}

/// El icono del Dock que llega de Dart.
///
/// Lo que no puede pasar es que un PNG roto deje el Dock con un hueco: el
/// icono que había se queda.
final class IconoDelDockTests: XCTestCase {
  override func tearDown() {
    NexusDock.quitar()
    super.tearDown()
  }

  private func png(_ color: NSColor) -> Data {
    let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 64,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    color.setFill()
    NSRect(x: 0, y: 0, width: 64, height: 64).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
  }

  func testUnPngBuenoSePone() {
    XCTAssertTrue(NexusDock.poner(png(.systemTeal)))
    XCTAssertEqual(NSApplication.shared.applicationIconImage?.size, NSSize(width: 64, height: 64))
  }

  func testLoQueNoSeEntiendeDejaElQueHabia() {
    XCTAssertTrue(NexusDock.poner(png(.systemPurple)))
    let antes = NSApplication.shared.applicationIconImage

    XCTAssertFalse(NexusDock.poner(Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0x01])), "un PNG cortado")
    XCTAssertFalse(NexusDock.poner(Data()), "vacío")
    XCTAssertFalse(NexusDock.poner(nil), "sin datos")

    XCTAssertTrue(
      NSApplication.shared.applicationIconImage === antes,
      "un icono ilegible no puede sustituir al que había"
    )
  }

  func testQuitarVuelveAlDelPaquete() {
    XCTAssertTrue(NexusDock.poner(png(.systemOrange)))
    let puesto = NSApplication.shared.applicationIconImage

    NexusDock.quitar()

    // Con `nil` AppKit no deja el Dock vacío: vuelve a enseñar el del paquete.
    XCTAssertNotNil(NSApplication.shared.applicationIconImage)
    XCTAssertFalse(NSApplication.shared.applicationIconImage === puesto)
  }
}

/// Cuándo se avisa de que un encargo terminó.
///
/// Lo que se prueba es **la decisión**, no la entrega: mandar un aviso de verdad
/// depende del permiso del sistema, que una prueba no puede fijar, y dejaría un
/// aviso colgado en la barra de quien corra la suite.
final class AvisosTests: XCTestCase {
  func testConLaAppDelanteNoSeAvisa() {
    // Avisar de algo que tienes delante es ruido, y el ruido enseña a ignorar
    // los avisos siguientes — que son los que sí importaban.
    XCTAssertFalse(NexusNotifications.shouldNotify(appIsActive: true))
  }

  func testConLaAppDetrasSiSeAvisa() {
    // Es el caso entero por el que esto existe: un encargo dura minutos y te vas
    // a otra cosa.
    XCTAssertTrue(NexusNotifications.shouldNotify(appIsActive: false))
  }
}

/// Si esta copia de la app **puede** actualizarse.
///
/// El caso malo es silencioso, y es el que le pasa a cualquiera: una app que se
/// baja, se abre desde Descargas y nunca se arrastra a Aplicaciones. macOS la
/// ejecuta desde una copia de solo lectura con ruta aleatoria —traslocación de
/// Gatekeeper— y desde ahí **no hay nada que reemplazar**. El paquete parece
/// intacto por dentro; lo único que lo delata es la ruta.
///
/// Medido en esta máquina el día que se escribió: la 0.0.1 instalada estaba en
/// `~/Downloads/Nexus.app`, es decir, exactamente en el caso malo.
///
/// La función está separada del sistema de archivos justo para poder probar esto:
/// una prueba no puede montar una ruta traslocada de verdad.
final class ActualizadorTests: XCTestCase {
  func testUnaRutaTraslocadaNoSePuedeActualizar() {
    let ruta =
      "/private/var/folders/9x/abc/T/AppTranslocation/1E2F-3A4B/d/Nexus.app"
    XCTAssertEqual(
      NexusUpdater.installability(bundlePath: ruta, writable: true),
      .translocated,
      "una copia traslocada no puede reemplazarse aunque se pueda escribir en su carpeta"
    )
  }

  func testEnAplicacionesSePuede() {
    XCTAssertEqual(
      NexusUpdater.installability(bundlePath: "/Applications/Nexus.app", writable: true),
      .ok
    )
  }

  func testDondeNoSePuedeEscribirTampoco() {
    XCTAssertEqual(
      NexusUpdater.installability(bundlePath: "/Applications/Nexus.app", writable: false),
      .readOnly
    )
  }

  /// La traslocación gana sobre lo escribible, y el orden importa: si se
  /// comprobara primero si se puede escribir, una copia traslocada montada como
  /// escribible se declararía instalable y el fallo saldría al final de la
  /// descarga.
  func testLaTraslocacionSeMiraAntesQueLoEscribible() {
    XCTAssertEqual(
      NexusUpdater.installability(
        bundlePath: "/private/var/folders/x/AppTranslocation/d/Nexus.app",
        writable: false
      ),
      .translocated
    )
  }
}

/// El punto rojo del icono de la barra.
///
/// Lo que se vigila es la trampa que ya costó un icono gris: **una plantilla se
/// tiñe entera**. Si el icono con punto siguiera siendo plantilla, macOS pintaría
/// el rojo del color de la barra y el punto dejaría de decir nada — exactamente el
/// mismo fallo que dejó el cian del icono de 16 px en gris azulado.
final class PuntoPendienteTests: XCTestCase {
  private func imagen(_ estado: String, pendiente: Bool) -> NSImage? {
    NexusStatusItem.show(NexusStatusItem.Presence.from(estado), pending: pendiente)
    return NexusStatusItem.currentImage
  }

  func testConPuntoNoEsPlantilla() {
    XCTAssertEqual(imagen("sleep", pendiente: false)?.isTemplate, true,
                   "dormido sin nada pendiente sí se tiñe: así se ve en barra clara y oscura")
    XCTAssertEqual(imagen("sleep", pendiente: true)?.isTemplate, false,
                   "con punto no puede teñirse, o el rojo se pierde")
  }

  func testElPuntoSeVeDistinto() {
    let sin = imagen("sleep", pendiente: false)?.tiffRepresentation
    let con = imagen("sleep", pendiente: true)?.tiffRepresentation
    XCTAssertNotNil(sin)
    XCTAssertNotEqual(sin, con, "el punto tiene que dibujarse, no solo declararse")
  }

  /// Y que sobreviva a un cambio de estado del orbe.
  ///
  /// Es el fallo que este diseño evita: el estado del orbe cambia varias veces por
  /// turno y el aviso casi nunca, así que si `show` no recordara el pendiente, el
  /// punto se borraría en cuanto Claude empezara a pensar.
  func testElPuntoSobreviveAlCambioDeEstado() {
    _ = imagen("sleep", pendiente: true)

    // El estado del orbe se manda **sin decir nada del pendiente**, que es como
    // llega de verdad: `status_presence.dart` reenvía el estado en cada cambio y
    // el aviso solo cuando cambia el aviso.
    NexusStatusItem.show(.working)

    XCTAssertEqual(
      NexusStatusItem.currentImage?.isTemplate, false,
      "sin recordar el pendiente, el punto se borraría en cuanto Claude pensara"
    )
  }
}

/// El acento del icono de la barra, que llega desde Dart como texto.
///
/// Viaja como `#RRGGBB` porque el color se elige en Ajustes y el icono se dibuja
/// en Swift. Lo que se vigila es el caso feo: un texto mal formado **no puede**
/// convertirse en negro, porque un icono negro sobre una barra oscura desaparece
/// sin dejar rastro de por qué.
final class AcentoDeLaBarraTests: XCTestCase {
  func testUnHexValidoSeLee() {
    let color = NexusStatusItem.color(fromHex: "#B79BFF")
    XCTAssertNotNil(color)
    XCTAssertEqual(color?.redComponent ?? 0, CGFloat(0xB7) / 255, accuracy: 0.001)
    XCTAssertEqual(color?.greenComponent ?? 0, CGFloat(0x9B) / 255, accuracy: 0.001)
    XCTAssertEqual(color?.blueComponent ?? 0, CGFloat(0xFF) / 255, accuracy: 0.001)
  }

  func testSinAlmohadillaTambien() {
    XCTAssertNotNil(NexusStatusItem.color(fromHex: "56E1EA"))
  }

  /// Y lo que no es un color devuelve `nil` para que el icono se quede con el que
  /// ya tenía, en vez de pintarse de negro.
  func testLoQueNoEsUnColorNoSeInventa() {
    XCTAssertNil(NexusStatusItem.color(fromHex: ""))
    XCTAssertNil(NexusStatusItem.color(fromHex: "#FFF"))
    XCTAssertNil(NexusStatusItem.color(fromHex: "violeta"))
    XCTAssertNil(NexusStatusItem.color(fromHex: "#ZZZZZZ"))
  }

  func testElIconoSePintaConElAcentoQueLlega() {
    // Dos acentos distintos tienen que dar dos dibujos distintos; si el icono
    // ignorara el que llega, esto sería el mismo mapa de bits dos veces.
    NexusStatusItem.show(.active, pending: false, accent: "#B79BFF")
    let violeta = NexusStatusItem.currentImage?.tiffRepresentation
    NexusStatusItem.show(.active, pending: false, accent: "#F5C451")
    let ambar = NexusStatusItem.currentImage?.tiffRepresentation
    XCTAssertNotNil(violeta)
    XCTAssertNotEqual(violeta, ambar)
  }
}

/// El motor de audio son 797 líneas y **ninguna prueba** hasta ahora: es la
/// parte donde un fallo mata la app entera en vez de enseñar un error, y la
/// única que las pruebas de Dart no pueden ver.
///
/// Casi todo él necesita hardware. Lo que sí se puede fijar es la decisión que
/// no lo necesita —cuándo un bloque tardío es un corte— y el contrato de
/// formatos con el servicio de voz, que si cambia en silencio se oye como ruido.
final class MotorDeAudioTests: XCTestCase {
  private let momento = Date(timeIntervalSince1970: 1_800_000_000)

  func testUnCorteAMediaFraseSeCuenta() {
    let ms = HuecoDeReproduccion.mide(
      vaciaDesde: momento,
      ahora: momento.addingTimeInterval(0.5),
      yaSono: true
    )

    XCTAssertEqual(ms, 500)
  }

  /// El número que motivó el tope: sin él, la primera medición apuntó un
  /// «hueco» de 9,5 s que era el rato entre una respuesta y la siguiente.
  func testElRatoEntreDosRespuestasNoEsUnCorte() {
    XCTAssertNil(
      HuecoDeReproduccion.mide(
        vaciaDesde: momento,
        ahora: momento.addingTimeInterval(9.5),
        yaSono: true
      ),
      "un silencio así no es un corte a media frase: es que la respuesta acabó"
    )
  }

  func testJustoEnElTopeYaNoCuenta() {
    let limite = Double(HuecoDeReproduccion.maxMs) / 1000
    XCTAssertNil(
      HuecoDeReproduccion.mide(
        vaciaDesde: momento, ahora: momento.addingTimeInterval(limite), yaSono: true
      )
    )
    XCTAssertNotNil(
      HuecoDeReproduccion.mide(
        vaciaDesde: momento,
        ahora: momento.addingTimeInterval(limite - 0.001),
        yaSono: true
      )
    )
  }

  /// El silencio de antes de que empiece a hablar no es un corte, es esperar.
  func testAntesDelPrimerSonidoNoHayCortes() {
    XCTAssertNil(
      HuecoDeReproduccion.mide(
        vaciaDesde: momento,
        ahora: momento.addingTimeInterval(0.5),
        yaSono: false
      )
    )
  }

  /// La cola nunca llegó a vaciarse: no hubo silencio que medir.
  func testSinColaVaciaNoHayNadaQueMedir() {
    XCTAssertNil(
      HuecoDeReproduccion.mide(vaciaDesde: nil, ahora: momento, yaSono: true)
    )
  }
}

/// Impedir que el Mac se duerma es lo único de aquí que se **queda puesto** si
/// alguien se equivoca: una aserción sin soltar deja el Mac despierto para
/// siempre, y el síntoma —«mi Mac ya no se duerme»— no apunta a esta app.
final class EnergiaTests: XCTestCase {
  override func tearDown() {
    NexusPower.permitirDormir()
    super.tearDown()
  }

  func testPedirloDosVecesNoCreaDos() {
    XCTAssertTrue(NexusPower.mantenerDespierto(motivo: "una prueba"))
    let primera = NexusPower.asercionViva

    XCTAssertTrue(NexusPower.mantenerDespierto(motivo: "otra vez"))

    XCTAssertEqual(
      NexusPower.asercionViva, primera,
      "la segunda petición tiene que reusar la que ya hay: dos aserciones son una que nadie suelta"
    )
  }

  func testSoltarlaLaSuelta() {
    _ = NexusPower.mantenerDespierto(motivo: "una prueba")
    XCTAssertNotNil(NexusPower.asercionViva)

    NexusPower.permitirDormir()

    XCTAssertNil(NexusPower.asercionViva)
  }

  func testSoltarSinHaberPedidoNoRompe() {
    NexusPower.permitirDormir()
    NexusPower.permitirDormir()
  }
}

/// «Quedarse sin imagen es el único resultado inservible», dice el propio
/// archivo. Esto lo comprueba: para lo que QuickLook no sabe representar tiene
/// que caer al icono del sistema y devolver algo igual.
final class MiniaturasTests: XCTestCase {
  private var carpeta: URL!

  override func setUpWithError() throws {
    carpeta = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("nexus-miniaturas-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: carpeta)
  }

  private func pedirMiniatura(de archivo: URL, timeout: TimeInterval = 20) throws -> Data? {
    var datos: Data?
    let lista = expectation(description: "la miniatura")
    NexusThumbnails.miniatura(ruta: archivo.path, tamano: 64, escala: 2) { png in
      datos = png
      lista.fulfill()
    }
    wait(for: [lista], timeout: timeout)
    return datos
  }

  func testUnCodigoSinPreviaCaeAlIconoDelSistema() throws {
    let archivo = carpeta.appendingPathComponent("main.dart")
    try "void main() {}".write(to: archivo, atomically: true, encoding: .utf8)

    let png = try pedirMiniatura(de: archivo)

    XCTAssertNotNil(png, "sin imagen no hay nada que enseñar, que es el único final inservible")
    // Y es un PNG de verdad, no bytes cualesquiera: los ocho de su firma.
    XCTAssertEqual(png?.prefix(8), Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
  }

  func testUnaImagenTambienDevuelveAlgo() throws {
    let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: 40, pixelsHigh: 40,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.systemTeal.setFill()
    NSRect(x: 0, y: 0, width: 40, height: 40).fill()
    NSGraphicsContext.restoreGraphicsState()

    let archivo = carpeta.appendingPathComponent("captura.png")
    try rep.representation(using: .png, properties: [:])!.write(to: archivo)

    XCTAssertNotNil(try pedirMiniatura(de: archivo))
  }

  func testUnArchivoQueNoExisteNoDejaColgado() throws {
    // Sin miniatura ni icono, el resultado puede ser nulo — lo que no puede es
    // no llegar: quien pidió se quedaría esperando para siempre.
    _ = try pedirMiniatura(de: carpeta.appendingPathComponent("no-existe.zip"))
  }
}

// MARK: - Para qué se pide el motor de audio

/// La única decisión del propósito, y la que se rompe en silencio.
///
/// 🔴 Reutilizar un motor montado **solo para hablar** cuando lo que se pide es
/// conversar deja la conversación **sorda sin dar ningún error**: el grafo está
/// montado y en marcha, `engine.start()` no se queja, y simplemente no hay tap
/// ni conversores de captura. No hay excepción que atrapar ni log que mirar —
/// solo un micrófono que no entrega nada.
///
/// Lo demás del motor pide hardware. Esto no, y es justo lo que hay que sujetar.
final class PropositoDelMotorTests: XCTestCase {
  func testSinMotorMontadoNoSirveNada() {
    XCTAssertFalse(NexusAudioEngine.sirve(montado: nil, para: .hablar))
    XCTAssertFalse(NexusAudioEngine.sirve(montado: nil, para: .conversar))
  }

  func testConversarYaTraeElReproductor() {
    XCTAssertTrue(
      NexusAudioEngine.sirve(montado: .conversar, para: .hablar),
      "un aviso que solo habla no tiene por qué rehacer el grafo entero"
    )
    XCTAssertTrue(NexusAudioEngine.sirve(montado: .conversar, para: .conversar))
  }

  func testHablarSirveParaHablar() {
    XCTAssertTrue(NexusAudioEngine.sirve(montado: .hablar, para: .hablar))
  }

  func testHablarNoSirveParaConversar() {
    XCTAssertFalse(
      NexusAudioEngine.sirve(montado: .hablar, para: .conversar),
      "solo salida no tiene captura, y no se le puede añadir en caliente: "
        + "reutilizarlo deja la conversación sorda y sin un solo error"
    )
  }

  // 🔴 **Cuánto se queda el motor caliente después de colgar.**
  //
  // Reportado así: «estoy escuchando música en los airpods y no se escucha», y
  // una notificación que tampoco sonó. La causa no es el cancelador de eco: es
  // el micrófono, que seguía abierto el minuto entero de la ventana caliente.
  // Unos auriculares Bluetooth conmutan al perfil de llamada en cuanto una app
  // abre la entrada, y ese perfil no lleva música.
  //
  // Lo que se rompe aquí no lanza nada: solo deja al Mac sin audio para lo
  // demás, un minuto, después de una conversación ya terminada.
  func testConAuricularesSeDesmontaAlColgar() {
    XCTAssertTrue(
      NexusAudioEngine.hayQueDesmontarAlColgar(
        montado: .conversar,
        salidaEsAltavozInterno: false
      ),
      "el minuto caliente solo amortiza el agregado del cancelador, y ese no "
        + "se monta con auriculares: quedaba el precio y ninguna ganancia"
    )
  }

  func testConElAltavozInternoSeQuedaCaliente() {
    XCTAssertFalse(
      NexusAudioEngine.hayQueDesmontarAlColgar(
        montado: .conversar,
        salidaEsAltavozInterno: true
      ),
      "aquí sí hay agregado que reutilizar, y es la decisión que se tomó"
    )
  }

  // Solo salida nunca abrió la entrada, así que no hay perfil que conmutar ni
  // nada que devolverle a nadie.
  func testSoloHablarNoTieneQueDesmontarse() {
    XCTAssertFalse(
      NexusAudioEngine.hayQueDesmontarAlColgar(
        montado: .hablar,
        salidaEsAltavozInterno: false
      )
    )
    XCTAssertFalse(
      NexusAudioEngine.hayQueDesmontarAlColgar(
        montado: nil,
        salidaEsAltavozInterno: false
      )
    )
  }

  /// El propósito viaja por el canal como cadena, así que un cambio de nombre
  /// aquí es un `nil` en el otro lado —y `nil` cae en `.conversar`, o sea el
  /// micrófono encendido para decir una frase, que es el fallo que se vino a
  /// arreglar.
  func testLosNombresQueViajanPorElCanal() {
    XCTAssertEqual(PropositoDelMotor(rawValue: "hablar"), .hablar)
    XCTAssertEqual(PropositoDelMotor(rawValue: "conversar"), .conversar)
    XCTAssertNil(PropositoDelMotor(rawValue: "solo_salida"))
  }
}

/// Lo que se dice después del nombre, que es lo que viaja como primer turno.
///
/// 🔴 Se perdía: la escucha paraba en el primer parcial que traía «hestia», y
/// «Hestia, ¿qué reuniones tengo?» llegaba como «Hestia».
final class LaFraseTrasElNombreTests: XCTestCase {
  func testLoQueSigueAlNombreConSusAcentos() {
    XCTAssertEqual(
      NexusEscucha.loQueSigueAlNombre("Hestia, ¿qué reuniones tengo?", siendo: ["hestia"]),
      "¿qué reuniones tengo?")
  }

  func testSoloElNombreNoDejaNada() {
    XCTAssertEqual(NexusEscucha.loQueSigueAlNombre("Hestia", siendo: ["hestia"]), "")
    XCTAssertEqual(NexusEscucha.loQueSigueAlNombre("Hestia.", siendo: ["hestia"]), "")
  }

  func testComoLaTranscribaElReconocedorTambien() {
    // «Estia» es como el reconocedor escribe «Hestia» a menudo: una letra.
    XCTAssertEqual(
      NexusEscucha.loQueSigueAlNombre("oye Estia corre los tests", siendo: ["hestia"]),
      "corre los tests")
  }

  func testSiSaleDosVecesCuentaLaUltima() {
    XCTAssertEqual(
      NexusEscucha.loQueSigueAlNombre("Hestia, no, Hestia, abre el repo", siendo: ["hestia"]),
      "abre el repo")
  }
}

/// Si en lo que se oyó está su nombre, escrito como lo escriba el reconocedor.
///
/// Suena igual, vale; se le parece, en un nombre corto, no: «cielo», «piel» o
/// «si el» no son «Ciel».
final class ElNombreQueSeOyeTests: XCTestCase {
  func testComoSuenaIgualAunqueSeEscribaDistinto() {
    XCTAssertEqual(NexusEscucha.comoSuena("ciel"), NexusEscucha.comoSuena("siel"))
    XCTAssertEqual(NexusEscucha.comoSuena("hestia"), NexusEscucha.comoSuena("estia"))
    XCTAssertEqual(NexusEscucha.comoSuena("zyel"), NexusEscucha.comoSuena("siel"))
    XCTAssertEqual(NexusEscucha.comoSuena("chema"), "chema")
  }

  func testLaOyeComoLaEscribaElReconocedor() {
    XCTAssertTrue(NexusEscucha.leLlamaron("ciel que hora es", siendo: ["ciel"]))
    XCTAssertTrue(NexusEscucha.leLlamaron("siel que hora es", siendo: ["ciel"]))
    XCTAssertTrue(NexusEscucha.leLlamaron("oye estia abre el repo", siendo: ["hestia"]))
    XCTAssertTrue(NexusEscucha.leLlamaron("hola señor jarvis", siendo: ["señor jarvis"]))
  }

  /// 🔴 Visto el 27 sep con la tele encendida: la 1.27.2 abría con «si el…» y
  /// desde antes con cualquier palabra que llevara el nombre dentro.
  func testNoAbreConLoQueSeLeParece() {
    XCTAssertFalse(NexusEscucha.leLlamaron("pasame el cafe", siendo: ["ciel"]))
    XCTAssertFalse(NexusEscucha.leLlamaron("si el test pasa lo subimos", siendo: ["ciel"]))
    XCTAssertFalse(NexusEscucha.leLlamaron("mira el cielo", siendo: ["ciel"]))
    XCTAssertFalse(NexusEscucha.leLlamaron("tengo la piel seca", siendo: ["ciel"]))
    XCTAssertFalse(NexusEscucha.leLlamaron("cien pesos", siendo: ["ciel"]))
    XCTAssertFalse(NexusEscucha.leLlamaron("hablemos de la reunion", siendo: ["hestia"]))
  }
}

/// El orbe de fuera, del tamaño y en el sitio del mockup.
///
/// En el mockup es un orbe de 210 a 28 del borde, abajo a la derecha, en una
/// pantalla de 1280 dibujada a escala. Salía de 148 a 24, y a ese tamaño el
/// anillo de barras y el reloj se quedaban en un borrón: se veía que había
/// algo, no qué estaba haciendo.
final class ElOrbeFlotanteTests: XCTestCase {
  func testMideLoDelMockupYVaAbajoALaDerecha() {
    let pantalla = NSRect(x: 0, y: 40, width: 1440, height: 860)
    let marco = NexusOrbeFlotante.dondeVa(en: pantalla)

    XCTAssertEqual(marco.width, 210)
    XCTAssertEqual(marco.height, 210)
    // AppKit cuenta desde abajo: `minY` es el borde de abajo de lo visible,
    // que ya deja fuera el Dock.
    XCTAssertEqual(marco.maxX, pantalla.maxX - 28)
    XCTAssertEqual(marco.minY, pantalla.minY + 28)
  }

  func testSeFundeEnElMedioSegundoDelMockup() {
    XCTAssertEqual(NexusOrbeFlotante.fundido, 0.5)
  }
}

/// Con qué idioma se escucha: **el de la app**, con el del sistema de respaldo.
///
/// 🔴 Salió al escribir la guía de configuración de la voz (30 sep): el oído
/// reconocía con el idioma del sistema y la voz hablaba el de la app, así que
/// con el Mac en español y la app en inglés ella contestaba en inglés y el oído
/// esperaba oírte en español.
final class ElIdiomaDelOidoTests: XCTestCase {
  let soportados = ["en-GB", "en-US", "en-AU", "es-CO", "es-ES", "es-MX", "fr-FR"]

  func testMandaElIdiomaDeLaAppAunqueElSistemaSeaOtro() {
    let orden = NexusEscucha.losCandidatos(
      idiomaDeLaApp: "en", preferidos: ["es-CO"], soportados: soportados)
    XCTAssertEqual(orden.first, "en-US")
    XCTAssertEqual(Array(orden.prefix(3)), ["en-US", "en-AU", "en-GB"])
  }

  func testTuVarianteVaPrimeroSiEsDelIdiomaDeLaApp() {
    let orden = NexusEscucha.losCandidatos(
      idiomaDeLaApp: "es", preferidos: ["es-CO", "en-US"], soportados: soportados)
    // «es-CO» existe y no trabaja en el Mac: por eso detrás van sus hermanas.
    XCTAssertEqual(Array(orden.prefix(3)), ["es-CO", "es-ES", "es-MX"])
  }

  func testElDelSistemaQuedaDeRespaldoYNoSeMezcla() {
    let orden = NexusEscucha.losCandidatos(
      idiomaDeLaApp: "en", preferidos: ["es-CO"], soportados: soportados)
    let ingles = orden.prefix { $0.hasPrefix("en") }
    let espanol = orden.drop { $0.hasPrefix("en") }
    XCTAssertEqual(ingles.count, 3)
    XCTAssertTrue(espanol.allSatisfy { $0.hasPrefix("es") })
    XCTAssertEqual(espanol.first, "es-CO")
    XCTAssertFalse(orden.contains("fr-FR"))
  }

  func testSinIdiomaDeLaAppSeEscuchaComoAntes() {
    let orden = NexusEscucha.losCandidatos(
      idiomaDeLaApp: nil, preferidos: ["es-CO"], soportados: soportados)
    XCTAssertEqual(orden, ["es-CO", "es-ES", "es-MX"])
  }

  func testLosGuionesBajosDelSistemaCuentanIgual() {
    let orden = NexusEscucha.losCandidatos(
      idiomaDeLaApp: "es", preferidos: ["en-US"], soportados: ["es_MX", "en_US"])
    XCTAssertEqual(orden, ["es-MX", "en-US"])
  }
}

/// Por qué no se pudo poner la escucha viaja **por su nombre** hasta Dart.
///
/// 🔴 Iba solo al registro unificado de macOS y a la app llegaba un `false`:
/// `nexus.log` decía «no se pudo poner» y ya. Estos nombres son el contrato
/// con `PorQueNoEscucha` de `escucha_channel.dart`, que fija los mismos.
final class PorQueNoEscuchaTests: XCTestCase {
  func testLosMotivosViajanPorSuNombre() {
    let nombres: [PorQueNoEscucha] = [
      .sinPalabras, .sinPermisoDeVoz, .sinPermisoDelMicrofono, .microfonoOcupado,
      .sinReconocedorLocal, .sinMicrofono, .fallaElMotor, .elAudioNoResponde,
    ]
    XCTAssertEqual(
      nombres.map(\.rawValue),
      [
        "sinPalabras", "sinPermisoDeVoz", "sinPermisoDelMicrofono", "microfonoOcupado",
        "sinReconocedorLocal", "sinMicrofono", "fallaElMotor", "elAudioNoResponde",
      ])
  }
}

/// 🔴 Con el servicio saturado el audio llega más lento de lo que suena —2 oct:
/// 38 huecos en una sesión, uno por segundo— y 400 ms fijos de colchón se
/// vaciaban a cada sílaba. Estos casos fijan cómo crece y cómo vuelve.
final class ElColchonQueCreceTests: XCTestCase {
  func testEmpiezaEnLoQueNoSeNota() {
    XCTAssertEqual(ElColchonQueCrece().segundos, ElColchonQueCrece.minimo)
  }

  func testCadaHuecoLoAgranda() {
    var colchon = ElColchonQueCrece()
    colchon.hubo(huecoMs: 319)
    XCTAssertEqual(colchon.segundos, 0.719, accuracy: 0.001, "al menos lo que duró el corte")
    colchon.hubo(huecoMs: 210)
    XCTAssertEqual(colchon.segundos, 0.719 * 1.5, accuracy: 0.001, "y al menos la mitad más")
  }

  func testNoPasaDelMaximo() {
    var colchon = ElColchonQueCrece()
    for _ in 0..<20 { colchon.hubo(huecoMs: 1387) }
    XCTAssertEqual(colchon.segundos, ElColchonQueCrece.maximo)
  }

  func testUnaRespuestaSinCortesLoEncoge() {
    var colchon = ElColchonQueCrece()
    colchon.hubo(huecoMs: 1000)
    colchon.otraRespuesta()
    XCTAssertEqual(colchon.segundos, 1.4, accuracy: 0.001, "la que tuvo el hueco no cuenta")
    colchon.otraRespuesta()
    XCTAssertEqual(colchon.segundos, 1.4 * 0.7, accuracy: 0.001)
    for _ in 0..<10 { colchon.otraRespuesta() }
    XCTAssertEqual(colchon.segundos, ElColchonQueCrece.minimo, "con buena conexión vuelve")
  }
}

/// Cuánto espera la escucha antes de volver a empezar cuando se le corta
/// seguido.
///
/// 🔴 Visto el 9 oct: con `coreaudiod` en bucle tras un cambio de auriculares,
/// volver a empezar al momento era volver a pedirle el micrófono a un audio que
/// no contestaba, una y otra vez.
final class LaEsperaDeLaEscuchaTests: XCTestCase {
  func testLaPrimeraVezVuelveAlMomento() {
    XCTAssertEqual(NexusEscucha.esperaAntesDeVolver(seguidos: 0), 0)
  }

  func testSeDoblaConCadaCorteSeguido() {
    XCTAssertEqual(NexusEscucha.esperaAntesDeVolver(seguidos: 1), 0.5)
    XCTAssertEqual(NexusEscucha.esperaAntesDeVolver(seguidos: 2), 1)
    XCTAssertEqual(NexusEscucha.esperaAntesDeVolver(seguidos: 4), 4)
  }

  func testNuncaPasaDeMedioMinuto() {
    XCTAssertEqual(NexusEscucha.esperaAntesDeVolver(seguidos: 7), 30)
    XCTAssertEqual(NexusEscucha.esperaAntesDeVolver(seguidos: 1000), 30)
  }
}
