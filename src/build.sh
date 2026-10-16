#!/bin/bash
cd "$(dirname "$0")"
body() { cat body.html; echo '<script>'; cat 01_core.js 01b_data.js 02_map.js 03_sim.js 03b_combat.js 04_ai.js 05_render.js 05b_sprites.js 06b_studio.js 06_ui.js; echo '</script>'; }
{ cat head.html; body; } > publish.html
{ echo '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">'; cat head.html; body; } > index.html
wc -c publish.html index.html
