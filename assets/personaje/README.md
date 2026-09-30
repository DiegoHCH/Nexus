# Las capas del personaje

Lo que va en la sala en vez del orbe cuando se elige en Ajustes › Apariencia ›
Orbe › Personaje (y en la conversación del móvil). Doce capas WebP con alfa,
pensadas para pintarse **una encima de otra en el mismo sitio**:

| Capa | Qué es |
| --- | --- |
| `base` | El busto entero, con los ojos abiertos y la boca cerrada. |
| `ojos-entornados`, `ojos-cerrados` | Solo la zona de los ojos, para pegar sobre la base. |
| `boca-a`, `boca-e`, `boca-o`, `boca-u` | Solo la boca, una por vocal. |
| `iris-base`, `iris-entornados` | Los iris en gris, con su forma, para teñirlos de otro color. |
| `traje-apagado`, `traje-luz` | Las líneas de luz de la chaqueta, apagadas y encendidas. |
| `traje-gris` | Las mismas encendidas, en gris, para teñirlas con el acento. |

## De dónde salen

Son **ilustraciones generadas**, no dibujadas a mano: la base con FLUX.1 [schnell]
y las variantes (ojos, bocas) con Gemini, partiendo de la base y a partir de una
descripción propia. No copian a ningún personaje existente. Después:

- se limpiaron y ampliaron con **Real-ESRGAN**;
- se recortaron del fondo con **rembg** (su modelo para anime);
- de cada variante se dejó solo su zona, con el borde difuminado, y las luces
  del traje se separaron de la chaqueta por su color.

## Alineadas, pero recortadas

Salieron todas a 1024 × 1381, alineadas al píxel. Aquí están **recortadas a lo
que dibujan**, con dos píxeles de aire transparente: decodificada, cada imagen
ocupa su tamaño entero en la memoria de la GPU, y doce a 1024 × 1381 eran 68 MB
para una boca de 220 × 198. Recortadas son unos 12 MB.

El sitio de cada una dentro de la capa entera vive en el código, en
`CapaDelPersonaje` (`lib/features/personaje/domain/el_personaje_por_capas.dart`),
y su pincel la vuelve a colocar ahí: para quien pinta, siguen siendo capas de
1024 × 1381. **Si se cambia una capa, se cambia también su rectángulo.** La base
va tal cual salió.

El movimiento —la malla, el parpadeo, las bocas, las luces por estado— sale del
mockup `nexus-ciel-2d.html`, que es la especificación.
