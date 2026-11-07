// Todos los números "de feel" del juego en un solo lugar.
export const CONFIG = {
  gravity: -24, // m/s²

  startAmmo: 5,
  headshotReward: 3, // balas por headshot (en lugar del +2 del kill normal)
  killReward: 2, // balas por kill al cuerpo

  // Retroceso: al disparar, la velocidad pasa a ser
  //   v = v * velocityKeep - dirCañón * recoilSpeed
  recoilSpeed: 12, // m/s en sentido contrario al cañón
  velocityKeep: 0.35, // cuánto de la velocidad previa se conserva
  spinOnShot: 8, // rad/s antihorario (el cañón "salta" hacia arriba)
  angularDamping: 0.15,

  bulletRange: 40, // m

  slowmoDuration: 1.0, // segundos reales
  slowmoScale: 0.2, // velocidad del tiempo durante el slow-mo
  slowmoRampOut: 0.3, // últimos segundos del slow-mo vuelven a 1 suavemente

  idleSpin: 2.2, // rad/s mientras el arma flota antes del primer disparo
  restSpeed: 0.3, // por debajo de esto el arma se considera quieta
  restTimeToGameOver: 0.8, // s quieta sin balas => game over
  maxEmptyTime: 6, // s sin balas => game over aunque siga rodando
};
