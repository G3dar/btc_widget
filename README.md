# BTC Widget - Bitcoin Price Widget for iOS

Widget de Bitcoin para iPhone que muestra el precio actual, gráfico de 6 horas, y valores máximo/mínimo.

## Características

- **Lock Screen Widgets**: Rectangular, Circular, e Inline
- **Home Screen Widgets**: Small y Medium
- **Actualización cada 5 minutos**
- **Gráfico de las últimas 6 horas**
- **Max/Min del período**
- **Porcentaje de cambio**

## Requisitos

- macOS con Xcode 14+
- iOS 16.0+
- Apple Developer Account (para instalar en dispositivo)

## Configuración del Proyecto en Xcode

### Paso 1: Crear nuevo proyecto

1. Abrir Xcode
2. File → New → Project
3. Seleccionar "App" bajo iOS
4. Configurar:
   - Product Name: `BTCWidget`
   - Team: Tu Apple Developer Team
   - Organization Identifier: `com.tuorganizacion`
   - Interface: SwiftUI
   - Language: Swift

### Paso 2: Añadir Widget Extension

1. File → New → Target
2. Seleccionar "Widget Extension" bajo iOS
3. Product Name: `BTCWidgetExtension`
4. **Desmarcar** "Include Configuration App Intent"
5. Finish

### Paso 3: Copiar archivos

Copiar los archivos de este proyecto a la estructura correspondiente:

```
BTCWidget/
├── BTCWidget/
│   ├── BTCWidgetApp.swift        (reemplazar)
│   └── ContentView.swift          (reemplazar)
├── BTCWidgetExtension/
│   ├── BTCWidgetBundle.swift      (reemplazar archivo generado)
│   ├── Models/                     (crear carpeta, añadir archivos)
│   │   ├── BitcoinData.swift
│   │   └── PriceEntry.swift
│   ├── Services/                   (crear carpeta, añadir archivos)
│   │   └── BitcoinAPIService.swift
│   ├── Provider/                   (crear carpeta, añadir archivos)
│   │   └── BTCTimelineProvider.swift
│   └── Views/                      (crear carpeta, añadir archivos)
│       ├── LockScreenWidgets.swift
│       ├── HomeScreenWidgets.swift
│       └── MiniChartView.swift
└── Shared/
    └── Extensions.swift            (añadir a ambos targets)
```

### Paso 4: Configurar Targets

1. Seleccionar el target `BTCWidgetExtension`
2. En Build Phases → Compile Sources, asegurarse que todos los archivos `.swift` estén incluidos
3. En Info.plist del widget, verificar que `NSExtensionPointIdentifier` sea `com.apple.widgetkit-extension`

### Paso 5: Permisos de Red

En el target principal y el widget, añadir en Info.plist:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

O mejor, usar:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>api.coingecko.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

## Agregar el Widget

### Lock Screen
1. Mantener presionado en la pantalla de bloqueo
2. Tocar "Personalizar"
3. Seleccionar área de widgets
4. Buscar "BTC Widget"
5. Elegir estilo (Rectangular recomendado)

### Home Screen
1. Mantener presionado en el Home Screen
2. Tocar el botón "+"
3. Buscar "BTC Widget"
4. Elegir tamaño (Medium recomendado)

## API Utilizada

[CoinGecko API](https://www.coingecko.com/en/api) - Gratuita, sin API key requerida.

## Estructura del Código

```
Models/
├── BitcoinData.swift      # Modelos de datos y respuestas API
└── PriceEntry.swift       # Entry para WidgetKit Timeline

Services/
└── BitcoinAPIService.swift  # Llamadas a CoinGecko API

Provider/
└── BTCTimelineProvider.swift  # Proveedor de timeline para widgets

Views/
├── LockScreenWidgets.swift   # Widgets para pantalla bloqueada
├── HomeScreenWidgets.swift   # Widgets para Home Screen
└── MiniChartView.swift       # Componente de gráfico sparkline
```

## Personalización

### Cambiar frecuencia de actualización

En `BTCTimelineProvider.swift`, modificar:
```swift
let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)
```

### Cambiar período del gráfico

En `BitcoinAPIService.swift`, modificar el parámetro `days`:
- `0.25` = 6 horas
- `0.5` = 12 horas
- `1` = 24 horas
