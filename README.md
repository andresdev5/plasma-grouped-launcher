# Plasma Grouped Launcher

Lanzador de aplicaciones para **KDE Plasma 6** basado en el "Lanzador de aplicaciones" (Kickoff) oficial, con **grupos plegables** y **carpetas** en Favoritos, al estilo del menú de inicio de Windows 10.

Todo lo demás (búsqueda, todas las aplicaciones, lugares, botones de energía, ajustes) se comporta igual que el lanzador original.

## Funciones

- **Grupos plegables** con nombre: crear, renombrar, plegar/expandir, reordenar y eliminar.
- **Carpetas**: se crean soltando una app sobre el centro de otra (o con el botón *Nueva carpeta*); al abrirlas se ven sus apps y se pueden renombrar.
- **Arrastrar y soltar**:
  - Soltar en el borde de otra app → reordena.
  - Soltar en otro grupo o en su encabezado → mueve la app a ese grupo (un grupo plegado se expande al mantener la app encima).
  - Soltar sobre una carpeta → la mete en la carpeta.
  - Soltar en la flecha *Volver* de una carpeta abierta → la saca de la carpeta.
- **Menú contextual** de cada app con *Mover a grupo ▸* y *Mover a carpeta ▸*.
- **Ajustes**: agrupar con *grupos plegables*, *carpetas* o *ambos*; favoritos en cuadrícula o en lista.
- Conserva los favoritos del lanzador original al cambiarlo con *Mostrar alternativas…*.

## Requisitos

- KDE Plasma 6 (desarrollado y probado con Plasma 6.8.2).

## Instalación

```sh
git clone https://github.com/andresdev5/plasma-grouped-launcher.git
cd plasma-grouped-launcher
./install.sh
```

Después, clic derecho en el ícono del menú de inicio → **Mostrar alternativas…** → **Lanzador de aplicaciones (grupos)** → **Cambiar**.

Tras actualizar (`git pull && ./install.sh`), reiniciar Plasma para recargar el widget:

```sh
systemctl --user restart plasma-plasmashell
```

## Desinstalación

Volver al lanzador original con *Mostrar alternativas…* y borrar la carpeta del widget:

```sh
rm -rf ~/.local/share/plasma/plasmoids/com.github.andresdev5.kickoffgroups
```

## Cómo guarda los grupos

Los grupos, carpetas y la pertenencia de cada favorito se guardan como JSON en la configuración del propio widget (`groupsData` en `~/.config/plasma-org.kde.plasma.desktop-appletsrc`). Los favoritos en sí siguen en la base de datos de actividades de KDE, igual que en el lanzador original.

## Limitaciones conocidas

- Al reordenar no hay animación en vivo: la app cambia de lugar al soltarla.
- Con el teclado se recorren las apps de todos los grupos, pero no las carpetas.
- Arrastrar un favorito fuera del menú no lo quita de Favoritos; se usa clic derecho → *Quitar de favoritos*.
- Los textos nuevos (grupos y carpetas) están en español; el resto usa las traducciones del lanzador de KDE.

## Créditos y licencia

Basado en el código del lanzador Kickoff de [plasma-desktop](https://invent.kde.org/plasma/plasma-desktop) (v6.8.2), © sus autores de KDE. Se distribuye bajo **GPL-2.0-or-later**; algunos archivos heredados están bajo LGPL-2.0-or-later (ver `LICENSES/` y la cabecera SPDX de cada archivo).
