import pandas as pd
import numpy as np
from scipy.signal import butter, filtfilt
import os

# === CONFIGURACIÓN ===
ruta_archivo = r"C:\IB\Proyecto-Integrativo-II\Base de datos\10 segundos\SM\SM14 .csv"
fs = 100     # Frecuencia de muestreo (Hz)
fc = 8       # Frecuencia de corte (Hz)
orden = 4    # Orden del filtro

# === FUNCIONES ===
def butter_lowpass(cutoff, fs, order=4):
    """Genera los coeficientes de un filtro Butterworth pasa-bajos."""
    nyq = fs / 2.0
    normal_cutoff = cutoff / nyq
    b, a = butter(order, normal_cutoff, btype='low', analog=False)
    return b, a

def aplicar_filtro_columna(columna, cutoff, fs, order):
    """Aplica el filtro Butterworth a una columna numérica."""
    b, a = butter_lowpass(cutoff, fs, order)
    return filtfilt(b, a, columna)

# === CARGAR DATOS ===
df = pd.read_csv(ruta_archivo)

# === FILTRAR TODAS LAS COLUMNAS NUMÉRICAS ===
df_filtrado = pd.DataFrame()
for col in df.columns:
    if np.issubdtype(df[col].dtype, np.number):
        print(f"Filtrando columna: {col}")
        df_filtrado[col + "_filt"] = aplicar_filtro_columna(df[col].values, cutoff=fc, fs=fs, order=orden)

# === GUARDAR RESULTADO ===
nombre_salida = os.path.splitext(ruta_archivo)[0] + "_filtrado.csv"
df_filtrado.to_csv(nombre_salida, index=False)

print(f"\n✅ Archivo filtrado guardado en:\n{nombre_salida}")
