# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
[English](./tmux.cheatsheet.md) | Español

# Tmux — Resumen y Cheatsheet

## 🚀 Resumen de modules/home/terminals/tmux.nix

### ⌨️ ¿Qué es el Prefijo de Tmux?

- El prefijo es una tecla especial que presionas antes de la mayoría de los comandos de tmux, para que tmux pueda distinguirlos de la escritura normal.
- Guía de notación utilizada a continuación:
    - C-x = mantén presionada la tecla Control y presiona x (ej., C-a significa Control+a)
    - M-x = mantén presionada la tecla Alt/Meta y presiona x (a veces se muestra como Alt+x)
    - S-x = mantén presionada la tecla Shift y presiona x (a menudo implícito para las letras mayúsculas)
- El prefijo predeterminado de Tmux es C-b (Control+b). En esta configuración se cambia a C-a (Control+a), lo que refleja el flujo de trabajo histórico de GNU Screen que muchos usuarios prefieren.

Ejemplos rápidos (con prefijo = C-a):

- Nueva ventana: presiona C-a y luego c
- Siguiente ventana: presiona C-a y luego n
- Dividir horizontalmente: presiona C-a y luego |
- Dividir verticalmente: presiona C-a y luego -
- Redimensionar a la izquierda: presiona C-a y luego C-h (mantén Control y presiona h)

- Programa
    - tmux habilitado; prefijo: C-a; modo de teclas: vi; baseIndex: 1; pane-base-index: 1
        - baseIndex: la numeración de las ventanas comienza en 1 en lugar de 0
        - pane-base-index: la numeración de los paneles dentro de una ventana comienza en 1 en lugar de 0
    - La terminal anula el RGB; la terminal se establece en "tmux-256color"; shell: zsh
    - Ratón: habilitado; reloj de 12 horas; límite de historial: 5000; renumerar ventanas: activado

- Estado/UX
    - Barra de estado en la parte superior; passthrough: activado; confirmaciones reducidas (kill-pane sin aviso)

- Plugins
    - vim-tmux-navigator, sensible, catppuccin

---

## 🗝️ Cheatsheet de Atajos de Teclado

Navegación

- Prefijo h/j/k/l — seleccionar panel Izquierda/Abajo/Arriba/Derecha
- Prefijo o — seleccionar el siguiente panel
- C-Tab — siguiente ventana
- C-S-Tab — ventana anterior
- M-Tab — nueva ventana
- M-h/M-j/M-k/M-l — seleccionar panel Izquierda/Abajo/Arriba/Derecha (sin prefijo)

Divisiones

- Prefijo | — dividir ventana -h (directorio actual)
- Prefijo \ — dividir ventana -fh (directorio actual)
- Prefijo - — dividir ventana -v (directorio actual)
- Prefijo \_ — dividir ventana -fv (directorio actual)

Redimensionar

- Prefijo C-h/C-k/C-l — redimensionar panel 15 columnas/filas en la dirección
- Prefijo m — alternar zoom (redimensionar panel -Z)

Modo de copia (vi)

- En modo de copia (vi), usa:
    - v — comenzar selección
    - C-v — alternar selección en bloque (rectangular)
    - y — copiar selección y salir del modo de copia

Ventanas

- Prefijo c — nueva ventana
- Prefijo p — ventana anterior
- Prefijo n — siguiente ventana
- M-1..M-9 — seleccionar ventana 1..9 (sin prefijo)
- Prefijo t — modo reloj
- Prefijo q — mostrar paneles
- Prefijo u — refrescar cliente

Sesión/Recargar

- Prefijo r — cargar archivo ~/.config/tmux/tmux.conf
- Prefijo x — matar panel (sin aviso)

Popups

- Prefijo C-y — abrir lazygit en un popup del 80% x 80% (directorio actual)
- Prefijo C-n — crear y cambiar a una nueva sesión de tmux mediante un popup interactivo
- Prefijo C-j — popup para cambiar de sesión con fzf (lista de sesiones tmux)
- Prefijo C-r — abrir el gestor de archivos yazi en un popup del 90% x 90% (directorio actual)
- Prefijo C-t — abrir una shell zsh en un popup del 75% x 75% (directorio actual)

Notas

- Los índices de paneles/ventanas comienzan en 1.
- Passthrough de terminal y RGB habilitados para color verdadero.
