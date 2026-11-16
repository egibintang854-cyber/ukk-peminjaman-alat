-- Struktur database aplikasi Peminjaman Alat.
-- Dibuat dari dump egi_xii1_paket1_ (3).sql.
-- Data akun, anggota, transaksi, dan log tidak disertakan.
-- Impor ke database baru/kosong; jangan jalankan pada database berisi data.
CREATE DATABASE IF NOT EXISTS `egi_xii1_paket1_`
  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `egi_xii1_paket1_`;
SET SQL_MODE = NO_AUTO_VALUE_ON_ZERO;
SET time_zone = +00:00;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE `alat` (
  `id_alat` int(11) NOT NULL,
  `nama_alat` varchar(100) DEFAULT NULL,
  `stok` int(11) DEFAULT NULL,
  `kondisi` varchar(50) DEFAULT NULL,
  `kategori` varchar(25) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `anggota` (
  `id_anggota` int(11) NOT NULL,
  `nomor_anggota` varchar(50) NOT NULL,
  `nama` varchar(100) NOT NULL,
  `alamat` varchar(255) NOT NULL DEFAULT '',
  `telepon` varchar(30) NOT NULL DEFAULT '',
  `id_user` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `kategori` (
  `id_kategori` int(11) NOT NULL,
  `nama_kategori` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `log_aktivitas` (
  `id_log` int(11) NOT NULL,
  `id_user` int(11) DEFAULT NULL,
  `aktivitas` varchar(255) DEFAULT NULL,
  `waktu` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `peminjam` (
  `id_peminjam` int(11) NOT NULL,
  `nama_peminjam` varchar(100) DEFAULT NULL,
  `id_alat` int(11) DEFAULT NULL,
  `tanggal_pinjam` date DEFAULT NULL,
  `jumlah_pinjam` int(11) DEFAULT NULL,
  `id_user` int(11) DEFAULT NULL,
  `batas_kembali` date DEFAULT NULL,
  `status` varchar(30) NOT NULL DEFAULT 'arsip'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `pengembalian` (
  `id_pengembalian` int(11) NOT NULL,
  `id_peminjam` int(11) DEFAULT NULL,
  `tanggal_kembali` date DEFAULT NULL,
  `kondisi_alat` varchar(50) DEFAULT NULL,
  `status` varchar(30) DEFAULT NULL,
  `denda` int(11) NOT NULL DEFAULT 0,
  `diverifikasi` tinyint(4) NOT NULL DEFAULT 0,
  `arsip` tinyint(4) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `user` (
  `id_user` int(11) NOT NULL,
  `username` varchar(50) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `nama` varchar(100) DEFAULT NULL,
  `level` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

ALTER TABLE `alat`
  ADD PRIMARY KEY (`id_alat`);

ALTER TABLE `anggota`
  ADD PRIMARY KEY (`id_anggota`),
  ADD UNIQUE KEY `nomor_anggota` (`nomor_anggota`),
  ADD UNIQUE KEY `id_user` (`id_user`);

ALTER TABLE `kategori`
  ADD PRIMARY KEY (`id_kategori`);

ALTER TABLE `log_aktivitas`
  ADD PRIMARY KEY (`id_log`);

ALTER TABLE `peminjam`
  ADD PRIMARY KEY (`id_peminjam`),
  ADD KEY `idx_pinjam_user` (`id_user`);

ALTER TABLE `pengembalian`
  ADD PRIMARY KEY (`id_pengembalian`),
  ADD KEY `idx_kembali_pinjam` (`id_peminjam`);

ALTER TABLE `user`
  ADD PRIMARY KEY (`id_user`),
  ADD UNIQUE KEY `uq_user_username` (`username`);

ALTER TABLE `alat`
  MODIFY `id_alat` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `anggota`
  MODIFY `id_anggota` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `kategori`
  MODIFY `id_kategori` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `log_aktivitas`
  MODIFY `id_log` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `peminjam`
  MODIFY `id_peminjam` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `pengembalian`
  MODIFY `id_pengembalian` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `user`
  MODIFY `id_user` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `anggota`
  ADD CONSTRAINT `fk_anggota_user` FOREIGN KEY (`id_user`) REFERENCES `user` (`id_user`);

ALTER TABLE `peminjam`
  ADD CONSTRAINT `fk_pinjam_user` FOREIGN KEY (`id_user`) REFERENCES `user` (`id_user`);

-- Function database untuk menghitung denda keterlambatan Rp1.000 per hari.
DROP FUNCTION IF EXISTS `hitung_denda`;
DELIMITER $$
CREATE FUNCTION `hitung_denda`(p_batas DATE, p_kembali DATE)
RETURNS INT
DETERMINISTIC
BEGIN
  RETURN GREATEST(DATEDIFF(p_kembali, p_batas), 0) * 1000;
END$$
DELIMITER ;

-- Procedure persetujuan dipanggil di dalam transaksi PHP yang sudah dimulai.
DROP PROCEDURE IF EXISTS `setujui_peminjaman`;
DELIMITER $$
CREATE PROCEDURE `setujui_peminjaman`(IN p_id_peminjam INT)
BEGIN
  DECLARE v_id_alat INT DEFAULT NULL;
  DECLARE v_jumlah INT DEFAULT NULL;
  DECLARE v_status VARCHAR(30) DEFAULT NULL;

  SELECT id_alat, jumlah_pinjam, status
    INTO v_id_alat, v_jumlah, v_status
    FROM peminjam
    WHERE id_peminjam = p_id_peminjam
    FOR UPDATE;

  IF v_id_alat IS NULL OR v_jumlah IS NULL OR v_jumlah < 1 OR v_status <> 'menunggu' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Peminjaman tidak valid atau sudah diproses.';
  END IF;

  UPDATE alat
    SET stok = stok - v_jumlah
    WHERE id_alat = v_id_alat AND stok >= v_jumlah;

  IF ROW_COUNT() <> 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stok alat tidak cukup.';
  END IF;

  UPDATE peminjam
    SET status = 'dipinjam'
    WHERE id_peminjam = p_id_peminjam;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER `log_status_pinjam` AFTER UPDATE ON `peminjam` FOR EACH ROW INSERT INTO log_aktivitas (id_user, aktivitas)
SELECT NEW.id_user, CONCAT('Status peminjaman #', NEW.id_peminjam, ': ', OLD.status, ' -> ', NEW.status)
WHERE OLD.status <> NEW.status
$$
DELIMITER ;

SET FOREIGN_KEY_CHECKS = 1;
