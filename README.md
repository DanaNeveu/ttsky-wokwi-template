
# Decodificador Morse a 7 Segmentos (Tiny Tapeout)

Proyecto desarrollado para el taller de TinyTapeout-CANELOS 2026. Este diseño implementa un decodificador de código Morse utilizando un único botón pulsador físico para ingresar puntos y guiones, mostrando el carácter alfanumérico resultante en un display de 7 segmentos.


## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## How it works

El sistema consta de cuatro módulos principales en Verilog:
1. **`debounce`**: Filtra el ruido mecánico y rebotes del botón físico.
2. **`morse_fsm`**: Máquina de estados que mide con precisión milimétrica la duración de cada pulsación (distinguiendo puntos `< 250ms` de guiones `>= 250ms`) y detecta pausas de silencio (`> 700ms`) para cerrar el carácter.
3. **`morse_to_7seg`**: Traductor combinacional que convierte los símbolos ingresados en patrones para un display de 7 segmentos (soportando letras A-Z, dígitos 0-9 y mostrando `=` en caso de error).
4. **`morse_top`**: Módulo principal que unifica todo y gestiona las señales de entrada (`btn`), reloj (`clk`), reset (`rst_n`) y salidas hacia el display (`hex`) y LEDs de estado.

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)

## What next?

- [Submit your design to the next shuttle](https://app.tinytapeout.com/).
- Edit [this README](README.md) and explain your design, how it works, and how to test it.
- Share your project on your social network of choice:
  - LinkedIn [#tinytapeout](https://www.linkedin.com/search/results/content/?keywords=%23tinytapeout) [@TinyTapeout](https://www.linkedin.com/company/100708654/)
  - Mastodon [#tinytapeout](https://chaos.social/tags/tinytapeout) [@matthewvenn](https://chaos.social/@matthewvenn)
  - X (formerly Twitter) [#tinytapeout](https://twitter.com/hashtag/tinytapeout) [@tinytapeout](https://twitter.com/tinytapeout)
  - Bluesky [@tinytapeout.com](https://bsky.app/profile/tinytapeout.com)
