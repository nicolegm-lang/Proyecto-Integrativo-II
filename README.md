# Proyecto-Integrativo-II
Clasificación de tres movimientos de la mano (arriba-abajo, izquierda-derecha y quieta) usando el sensor inercial WT9011DCL y modelos de Machine Learning. Se extraen y seleccionan características de señales IMU para entrenar clasificadores SVM, k-NN y arboles de desición.

En la carpeta "Base de datos" encontrará 3 carpetas principales llamadas: 10 segundos, Orden por movimiento y Orden por sujeto.

Orden por sujeto: mediciones obtenidas directamente con el sensor inerciales a tráves de la aplicación Wit Motion.

Orden por movimiento: las mediciones separadas por clase de movimiento donde la carpeta "AB" corresponde al movimiento arriba-abajo, "ID" a izquierda-derecha y "SM" a sin movimiento.

10 segundos: contiene las subcarpetas de las mediciones separadas por movimiento pero con duración estrictamente de 10 segundos (1000 muestras).

Por otra parte, la carpeta "Códigos" contiene los archivis .ipynb que puede ser ejecutados en JupyterNotebook, GoogleColab, VisualStudioCode etc. Para reproducir los códigos deberá cargar de la carpeta "Base de datos" los archivos .csv de cada clase de movimientos (AB,ID y SM).

Por último, se encuentra el protocolo experimental en archivo pdf, este muestra el procedimiento que se siguió para la obtención de señales con el sensor WT9011DCL.
