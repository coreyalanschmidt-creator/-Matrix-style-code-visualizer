import { app } from 'electron'
import { MatrixVisualizerApp } from './app'

const matrixVisualizerApp = new MatrixVisualizerApp()

if (!app.requestSingleInstanceLock()) {
  app.quit()
} else {
  void matrixVisualizerApp.start()
}
