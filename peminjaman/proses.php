<?php
// Sambungkan database.
require __DIR__ . '/../config/connection.php';
// Keputusan menyetujui atau menolak pengajuan hanya dapat dilakukan petugas.
masuk(['petugas']);
// Ambil ID pengajuan yang akan diproses petugas.
$id = id_dari_url();
if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    // Periksa token lalu kunci pengajuan supaya tidak diproses dua kali.
    cek_token();
    // Mulai transaksi: perubahan disimpan bersama setelah semua langkah berhasil.
    mysqli_begin_transaction($conn);
    $data = data_pinjam($id);
    if ($data['status'] != 'menunggu') {
        gagal('Peminjaman sudah diproses.');
    }
    $aksi = '';
    if (isset($_POST['aksi'])) {
        $aksi = $_POST['aksi'];
    }
    if ($aksi == 'setujui') {
        // Stored procedure mengurangi stok dan mengubah status dalam transaksi ini.
        try {
            $stmt = mysqli_prepare($conn, 'CALL setujui_peminjaman(?)');
            mysqli_stmt_bind_param($stmt, 'i', $id);
            mysqli_stmt_execute($stmt);
            mysqli_stmt_close($stmt);
        } catch (mysqli_sql_exception $error) {
            gagal('Peminjaman gagal diproses. Pastikan status masih menunggu dan stok cukup.');
        }
    } elseif ($aksi == 'tolak') {
        // Penolakan tidak mengubah stok, hanya memperbarui status pengajuan.
        mysqli_query($conn, "UPDATE peminjam SET status='ditolak' WHERE id_peminjam=$id");
    } else {
        gagal('Pilihan tidak valid.');
    }
    // Semua langkah berhasil, simpan perubahan ke database.
    mysqli_commit($conn);
    header('Location: tampil.php');
    exit();
}
$data = data_pinjam($id);

// Tampilkan ringkasan pengajuan untuk membantu petugas mengambil keputusan.
buka_halaman('Persetujuan Peminjaman');
?>
<h2>Persetujuan Peminjaman #<?php echo $id; ?></h2>
<p>Peminjam: <?php echo aman($data['nama_peminjam']); ?>, jumlah: <?php echo aman(
    $data['jumlah_pinjam'],
); ?></p>
<form method="post">
    <?php token(); ?>
    <button name="aksi" value="setujui">Setujui</button>
    <button name="aksi" value="tolak">Tolak</button>
</form>
<p><a href="tampil.php">Kembali</a>
</p>
<?php tutup_halaman(); ?>
