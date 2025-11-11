#  Proyecto Integrativo II  
### Sistema de Captura, Procesamiento y Clasificación de Movimientos de Mano

Este proyecto implementa un sistema completo para **reconocimiento de movimientos de la mano** utilizando sensores **IMU WT901 BLE**.  
Incluye una **interfaz gráfica en MATLAB App Designer** con dos modos de operación:

- ** Modo B – Adquisición**: Captura de datos directamente desde los sensores BLE (WT901).
- ** Modo A – Procesamiento offline**: Importación de archivos `.csv` previamente capturados para preprocesamiento, extracción de características y clasificación.



##  Estructura del repositorio

Proyecto-Integrativo-II/
│
├── Base de datos/
│   ├── 10 segundos/
│   │   ├── AB/               # Datos crudos
│   │   ├── AB_filtrado/      # Hampel + Butterworth
│   │   ├── ID/
│   │   ├── ID_filtrado/
│   │   ├── SM/
│   │   └── SM_filtrado/
│   │
│   ├── Orden por movimiento/
│   │   ├── AB/
│   │   ├── ID/
│   │   └── SM/
│   │
│   └── Orden por sujeto/
│       ├── S1/
│       ├── S2/
│       ├── S3/
│       ├── S4/
│       ├── S5/
│       ├── S6/
│       ├── S7/
│       └── S8/               # Datos individuales por sujeto
│
├── Códigos/
│   ├── Clasificacion.ipynb                # Clasificación de movimientos
│   ├── Procesamiento_de_senales.ipynb     # Preprocesamiento y filtrado
│   ├── Filtro pasa-bajas Butterworth.py   # Script filtro Butterworth
│   ├── visualizacion_mov_manos.ipynb      # Visualización de movimientos
│   └── caracteristicas.csv                # Archivo de características
│
├── Interfaz/
│   ├── app6.mlapp             # App MATLAB (modo A y B)
│   ├── DeviceModel.m          # Comunicación BLE con sensor WT901
│   ├── caracteristicas.csv    # Archivo de salida / features
│   ├── trainLogRegECOC.m      # Modelo de clasificación (ECOC)
│   └── Protocolo_experimental.pdf
│
├── README.md                  # Documentación principal del repositorio
└── LICENSE                    # Licencia del proyecto

##  Requisitos

###  MATLAB
- **Versión recomendada:** R2024b o R2025a  
- **Toolboxes necesarios:**
  - Bluetooth Toolbox  
  - Signal Processing Toolbox  
  - Statistics and Machine Learning Toolbox  

###  Python (para análisis y validación externa)
- Python 3.9+
- Librerías:
  ```bash
  pip install pandas numpy scipy matplotlib scikit-learn

### Autoras
-Fernanda Nicole Gómez Martínez
-Guadalupe Denisse Gónzalez Santos
