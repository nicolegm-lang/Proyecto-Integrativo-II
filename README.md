# Proyecto Integrativo II — Sistema de Captura, Procesamiento y Clasificación de Movimientos de Mano

Este repositorio contiene todo el flujo de trabajo del proyecto:
1. **Adquisición de datos** con un sensor IMU (WT901 BLE) desde MATLAB App Designer.
2. **Procesamiento y filtrado** (Hampel + Butterworth) en Python y MATLAB.
3. **Extracción de características y clasificación** mediante modelos supervisados.
4. **Base de datos organizada** por sujeto y tipo de movimiento.

---

##  Estructura general

| Carpeta | Descripción |
|----------|-------------|
| **Base de datos/** | Datos crudos y filtrados de los experimentos. |
| **Códigos/** | Notebooks y scripts para procesamiento, visualización y clasificación. |
| **Interfaz/** | Código de la App MATLAB (`app6.mlapp`) para captura BLE, calibración y guardado. |

---

##  Requisitos

### MATLAB
- MATLAB R2025a (o superior)
- Toolboxes necesarios:
  - **Bluetooth Toolbox**
  - **Signal Processing Toolbox**
  - **Statistics and Machine Learning Toolbox**

###  Python
- Python 3.9+
- Instalar dependencias:
  ```bash
  pip install pandas numpy scipy matplotlib scikit-learn


### Autoras
-Fernanda Nicole Gómez Martínez
-Guadalupe Denisse Gónzalez Santos
