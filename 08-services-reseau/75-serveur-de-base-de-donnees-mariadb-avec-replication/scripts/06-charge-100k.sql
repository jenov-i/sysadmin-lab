-- Charge de mesure : 100 000 lignes en une transaction.
-- Le moteur de sequences MariaDB genere les lignes sans script externe.
USE lab_boutique;
CREATE TABLE IF NOT EXISTS mesures (
  id     BIGINT AUTO_INCREMENT PRIMARY KEY,
  sonde  VARCHAR(16)     NOT NULL,
  releve DECIMAL(7,3)    NOT NULL,
  le     DATETIME(3)     NOT NULL,
  KEY idx_sonde_le (sonde, le)
) ENGINE = InnoDB;

TRUNCATE TABLE mesures;

INSERT INTO mesures (sonde, releve, le)
SELECT CONCAT('sonde-', 1 + (seq % 8)),
       ROUND(RAND() * 100, 3) - 50,
       NOW(3) - INTERVAL seq SECOND
FROM seq_1_to_100000;

SELECT COUNT(*) AS lignes, MIN(le) AS plus_ancien, MAX(le) AS plus_recent FROM mesures;
