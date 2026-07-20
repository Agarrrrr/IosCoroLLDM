#!/bin/sh

# Salir inmediatamente si ocurre un error
set -e

# Imprimir comandos ejecutados para depurar
set -x

# Navegar a la raíz del repositorio (dos carpetas arriba de ios/App/ci_scripts)
cd ../..

echo "=== Xcode Cloud: Instalando Node y dependencias web ==="

# Instalar dependencias de npm
npm ci

# Compilar los archivos web del visor
npm run build

# Sincronizar Capacitor para enlazar plugins nativos
npx cap sync ios

echo "=== Xcode Cloud: Preparación completada ==="
