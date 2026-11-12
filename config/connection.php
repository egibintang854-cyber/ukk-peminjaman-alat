<?php
// Nilai koneksi database untuk lingkungan lokal; hosting memakai kredensial dari panel.
$host = 'localhost';
$user = 'root';
$pass = '';
$db = 'egi_xii1_paket1_';

// Buka koneksi MySQL dan hentikan halaman bila database tidak dapat dijangkau.
$conn = mysqli_connect($host, $user, $pass, $db);

if (!$conn) {
    die('Koneksi gagal: ' . mysqli_connect_error());
}

// Gunakan UTF-8 penuh dan zona waktu aplikasi, lalu muat fungsi bersama.
mysqli_set_charset($conn, 'utf8mb4');
date_default_timezone_set('Asia/Jakarta');
include_once __DIR__ . '/fungsi.php';
?>
