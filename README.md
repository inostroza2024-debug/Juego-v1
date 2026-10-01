# Explora Duoc UC — Plaza Vespucio (V0.6) · Godot 4

1. Abre Godot 4.3+ → Importar → selecciona `project.godot` → F5.
2. **PC:** WASD mover · Shift correr · Espacio saltar · E interactuar · M mapa · ESC menú · mouse mirar. También gamepad.
3. **Móvil (Android / iOS / Web móvil):** joystick flotante a la izquierda para caminar · arrastra el dedo a la derecha para mirar · botones Saltar, Usar, Correr (activar/desactivar), Mapa y Menú. El botón "atrás" de Android abre/cierra el menú.
   Los controles táctiles aparecen solos en móviles y también al tocar la pantalla en una tablet/notebook táctil.

## Gráficos
- Texturas procedurales de 256 px con mapas de normales y rugosidad (baldosas, pasto, asfalto, madera, hormigón, fachadas con ventanas, cielo raso, etc.).
- Menú (☰ / ESC) → botón **Gráficos**: Baja / Media / Alta (MSAA, sombras, luces interiores, brillo).
  Por defecto: Alta en PC, Media en móvil.
- Para SSAO y reflejos de pantalla: Proyecto → Configuración → Rendering → Renderer → **Forward+** (PC) o **Mobile**.
  Ya está activado en el código y se aplica solo con esos renderers (no con Compatibility, que es el que usa la exportación web).

## Exportar a Android
1. Editor → Administrar plantillas de exportación → instalar.
2. Proyecto → Exportar → Android (necesita JDK y Android SDK configurados en Editor Settings).
3. `rendering/textures/vram_compression/import_etc2_astc` ya está activado.

Archivos: `sede_data.gd` (datos), `world.gd` (mundo 3D y texturas), `main.gd` (jugador, NPC, misiones, calidad), `ui.gd` (HUD/menús/mapa), `touch_controls.gd` (controles táctiles).
