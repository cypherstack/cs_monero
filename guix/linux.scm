;; Linux development manifest for cs_monero.
;;
;; Provides everything needed to:
;;   1. Build monero_c native libraries (C/C++ toolchain, cmake, boost, etc.)
;;   2. Build the Flutter Linux app (GTK, mesa, X11/Wayland, etc.)
;;
;; Enter this environment with:
;;   guix shell -m guix/linux.scm
;; Or reproducibly:
;;   guix time-machine -C guix/channels.scm -- shell -m guix/linux.scm

(use-modules (gnu packages)
             (gnu packages base)
             (gnu packages commencement)   ; gcc-toolchain
             (gnu packages llvm)           ; clang-toolchain
             (gnu packages cmake)
             (gnu packages ninja)
             (gnu packages pkg-config)
             (gnu packages autotools)      ; automake, autoconf, libtool
             (gnu packages gtk)            ; gtk+, pango, cairo, harfbuzz, gdk-pixbuf
             (gnu packages glib)
             (gnu packages gl)             ; mesa, libepoxy
             (gnu packages fontutils)      ; fontconfig, freetype
             (gnu packages freedesktop)    ; at-spi2-core
             (gnu packages xorg)
             (gnu packages compression)    ; xz, zlib
             (gnu packages version-control)
             (gnu packages curl)
             (gnu packages xdisorg)        ; libxkbcommon
             (gnu packages boost)
             (gnu packages tls)            ; openssl
             (gnu packages libunwind)
             (gnu packages python)         ; python (monero_c build)
             (gnu packages perl)
             (gnu packages certs)          ; nss-certs for https
             (gnu packages linux)          ; linux-libre-headers
             (guix profiles))

;; monero_c native build dependencies.
(define monero-c-packages
  (map specification->package
       (list
        ;; C/C++ toolchain
        "gcc-toolchain@13"
        "cmake"
        "make"
        "pkg-config"
        "autoconf"
        "automake"
        "libtool"

        ;; monero_c / monero dependencies
        "boost"
        "openssl"
        "libunwind"
        "python"
        "perl"

        ;; Kernel headers (linux/types.h needed by monero_c depends)
        "linux-libre-headers"

        ;; Utilities
        "git"
        "curl"
        "unzip"
        "xz"
        "which"
        "coreutils"
        "bash"
        "nss-certs")))

;; Flutter Linux build dependencies.
(define flutter-build-packages
  (map specification->package
       (list
        ;; Flutter uses clang for Linux builds
        "clang-toolchain"

        ;; Build systems
        "ninja"

        ;; GTK 3 — Flutter Linux embedding
        "gtk+"
        "glib"
        "pango"
        "cairo"
        "gdk-pixbuf"
        "harfbuzz"

        ;; OpenGL / EGL
        "mesa"
        "libepoxy"

        ;; Fonts
        "fontconfig"
        "freetype"

        ;; Accessibility
        "at-spi2-core"

        ;; X11 libs (Flutter Linux runner links against these)
        "libx11"
        "libxext"
        "libxrandr"
        "libxcursor"
        "libxfixes"
        "libxi"
        "libxinerama"
        "libxcomposite"
        "libxdamage"
        "libxrender"
        "libxtst"

        ;; Keyboard / Wayland
        "libxkbcommon"

        ;; Misc
        "zlib"
        "dbus")))

(packages->manifest
 (append monero-c-packages flutter-build-packages))
