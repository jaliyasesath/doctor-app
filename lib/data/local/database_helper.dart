import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {

  


  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('doctor_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return openDatabase(
      path,
     version: 26,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE doctors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        doctor_name TEXT,
        contact_number TEXT,
        email TEXT,
        city TEXT,
        specialization TEXT,
        role TEXT DEFAULT 'Doctor',
        medical_center_name TEXT,
        clinic_address TEXT,
        qualifications TEXT,
        profession TEXT,
        slmc_reg_no TEXT,
        affiliation TEXT,
        password TEXT,
        biometric_enabled INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'pending',
        updated_at TEXT,
        created_at TEXT,
        signature_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE patients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        doctor_id INTEGER,
        patient_name TEXT,
        patient_age TEXT,
        patient_gender TEXT,
        phone_number TEXT,
        address TEXT,
        notes TEXT,
        sync_status TEXT DEFAULT 'pending',
        updated_at TEXT,
        created_at TEXT,
        blood_group TEXT,
allergies TEXT,
chronic_diseases TEXT,
important_alerts TEXT,
queue_status TEXT DEFAULT 'Waiting',
queue_no INTEGER,
queue_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE prescriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        doctor_id INTEGER,
        patient_id INTEGER,
        server_patient_id INTEGER,
        patient_name TEXT,
        patient_age TEXT,
        patient_gender TEXT,
        prescription_no TEXT,
        prescription_date TEXT,
        items_text TEXT,
        complaint TEXT,
        diagnosis TEXT,
        visit_notes TEXT,
        sync_status TEXT DEFAULT 'pending',
        updated_at TEXT,
        created_at TEXT,
        blood_pressure TEXT,
        weight TEXT,
        pulse TEXT,
        temperature TEXT,
        spo2 TEXT,
        follow_up_date TEXT,
follow_up_note TEXT,
follow_up_status TEXT DEFAULT 'pending',
reminder_sent INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
  CREATE TABLE prescription_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    prescription_id INTEGER,
    medicine_name TEXT,
    dosage TEXT,
    frequency TEXT,
    duration TEXT,
    instructions TEXT,
    created_at TEXT
  )
''');

    await db.execute('''
      CREATE TABLE templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        complaint TEXT,
        diagnosis TEXT,
        items_json TEXT,
        is_favorite INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        doctor_id INTEGER,
        medicine_name TEXT NOT NULL,
        generic_name TEXT,
        brand_name TEXT,
        drug_group TEXT,
        dose_form TEXT,
        strength TEXT,
        is_favorite INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'pending',
        created_at TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE custom_instructions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        doctor_id INTEGER,
        instruction_text TEXT NOT NULL,
        usage_count INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'pending',
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
  CREATE TABLE custom_clinical_chips (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    doctor_id INTEGER,
    category TEXT,
    value TEXT,
    created_at TEXT
  )
''');
await _createIndexes(db);
  }
  

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {

    try {
  await db.execute(
    "ALTER TABLE doctors ADD COLUMN role TEXT DEFAULT 'Doctor'",
  );
} catch (_) {}

try {
  await db.execute('ALTER TABLE doctors ADD COLUMN specialization TEXT');
} catch (_) {}
    try {
      await db.execute('ALTER TABLE doctors ADD COLUMN server_id INTEGER');
    } catch (_) {}

    try {
      await db.execute(
        "ALTER TABLE doctors ADD COLUMN sync_status TEXT DEFAULT 'pending'",
      );
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE doctors ADD COLUMN updated_at TEXT');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE doctors ADD COLUMN qualifications TEXT');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE doctors ADD COLUMN profession TEXT');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE doctors ADD COLUMN slmc_reg_no TEXT');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE doctors ADD COLUMN affiliation TEXT');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE doctors ADD COLUMN signature_path TEXT');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE patients ADD COLUMN server_id INTEGER');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE patients ADD COLUMN doctor_id INTEGER');
    } catch (_) {}

    try {
      await db.execute(
        "ALTER TABLE patients ADD COLUMN sync_status TEXT DEFAULT 'pending'",
      );
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE patients ADD COLUMN updated_at TEXT');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE patients ADD COLUMN blood_group TEXT');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE patients ADD COLUMN allergies TEXT');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE patients ADD COLUMN chronic_diseases TEXT');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE patients ADD COLUMN important_alerts TEXT');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE prescriptions ADD COLUMN server_id INTEGER');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE prescriptions ADD COLUMN doctor_id INTEGER');
    } catch (_) {}

    try {
      await db.execute(
        'ALTER TABLE prescriptions ADD COLUMN server_patient_id INTEGER',
      );
    } catch (_) {}

    try {
      await db.execute(
        "ALTER TABLE prescriptions ADD COLUMN sync_status TEXT DEFAULT 'pending'",
      );
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE prescriptions ADD COLUMN updated_at TEXT');
    } catch (_) {}

    try {
      await db.execute(
        'ALTER TABLE prescriptions ADD COLUMN blood_pressure TEXT',
      );
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE prescriptions ADD COLUMN weight TEXT');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE prescriptions ADD COLUMN pulse TEXT');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE prescriptions ADD COLUMN temperature TEXT');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE prescriptions ADD COLUMN spo2 TEXT');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE prescriptions ADD COLUMN visit_notes TEXT');
    } catch (_) {}

    try {
      await db.execute(
        'ALTER TABLE templates ADD COLUMN is_favorite INTEGER DEFAULT 0',
      );
    } catch (_) {}

    if (oldVersion < 19) {
  try {
    await db.execute(
      'ALTER TABLE medicines ADD COLUMN is_deleted INTEGER DEFAULT 0',
    );
  } catch (_) {}

  try {
  await db.execute(
    "ALTER TABLE patients ADD COLUMN queue_status TEXT DEFAULT 'Waiting'",
  );
} catch (_) {}

try {
  await db.execute(
    'ALTER TABLE patients ADD COLUMN queue_no INTEGER',
  );
} catch (_) {}

try {
  await db.execute(
    'ALTER TABLE patients ADD COLUMN queue_date TEXT',
  );
} catch (_) {}

  if (oldVersion < 20) {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS prescription_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      prescription_id INTEGER,
      medicine_name TEXT,
      dosage TEXT,
      frequency TEXT,
      duration TEXT,
      instructions TEXT,
      created_at TEXT
    )
  ''');
}


}

    if (oldVersion < 17) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS medicines (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          server_id INTEGER,
          doctor_id INTEGER,
          medicine_name TEXT NOT NULL,
          generic_name TEXT,
          brand_name TEXT,
          drug_group TEXT,
          dose_form TEXT,
          strength TEXT,
          is_favorite INTEGER DEFAULT 0,
          sync_status TEXT DEFAULT 'pending',
          created_at TEXT,
          updated_at TEXT
        )
      ''');
    }

    if (oldVersion < 18) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS custom_instructions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          server_id INTEGER,
          doctor_id INTEGER,
          instruction_text TEXT NOT NULL,
          usage_count INTEGER DEFAULT 0,
          sync_status TEXT DEFAULT 'pending',
          created_at TEXT,
          updated_at TEXT
        )
      ''');
    }

    if (oldVersion < 23) {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS custom_clinical_chips (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      doctor_id INTEGER,
      category TEXT,
      value TEXT,
      created_at TEXT
    )
  ''');
}

if (oldVersion < 24) {
  try {
    await db.execute(
      'ALTER TABLE custom_clinical_chips ADD COLUMN doctor_id INTEGER',
    );
  } catch (_) {}
}

if (oldVersion < 25) {
  try {
    await db.execute(
      'ALTER TABLE prescriptions ADD COLUMN follow_up_date TEXT',
    );
  } catch (_) {}

  try {
    await db.execute(
      'ALTER TABLE prescriptions ADD COLUMN follow_up_note TEXT',
    );
  } catch (_) {}

  try {
    await db.execute(
      "ALTER TABLE prescriptions ADD COLUMN follow_up_status TEXT DEFAULT 'pending'",
    );
  } catch (_) {}

  try {
    await db.execute(
      'ALTER TABLE prescriptions ADD COLUMN reminder_sent INTEGER DEFAULT 0',
    );
  } catch (_) {}
}
if (oldVersion < 26) {
  await _createIndexes(db);
}
  }

  // =========================
  // DOCTORS
  // =========================

  Future<int> insertDoctor(Map<String, dynamic> data) async {
    final db = await database;

    data['sync_status'] ??= 'pending';
    data['updated_at'] ??= DateTime.now().toIso8601String();
    data['created_at'] ??= DateTime.now().toIso8601String();

    data['qualifications'] ??= '';
    data['profession'] ??= '';
    data['slmc_reg_no'] ??= '';
    data['affiliation'] ??= '';
    data['signature_path'] ??= '';

    return db.insert('doctors', data);
  }

  Future<int> updateDoctor(
  int id,
  Map<String, dynamic> data,
) async {
  final db = await database;

  data['updated_at'] = DateTime.now().toIso8601String();

  return db.update(
    'doctors',
    data,
    where: 'id = ?',
    whereArgs: [id],
  );
}

  Future<Map<String, dynamic>?> getDoctorByEmail(String email) async {
    final db = await database;

    final result = await db.query(
      'doctors',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );

    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>?> loginDoctor({
    required String email,
    required String password,
  }) async {
    final db = await database;

    final result = await db.query(
      'doctors',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
      limit: 1,
    );

    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getPendingDoctors() async {
    final db = await database;

    return db.query(
      'doctors',
      where: 'sync_status = ? OR sync_status = ?',
      whereArgs: ['pending', 'failed'],
      orderBy: 'id ASC',
    );
  }

  Future<void> markDoctorSynced(int localId, int serverId) async {
    final db = await database;

    await db.update(
      'doctors',
      {
        'server_id': serverId,
        'sync_status': 'synced',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> markDoctorSyncFailed(int localId) async {
    final db = await database;

    await db.update(
      'doctors',
      {
        'sync_status': 'failed',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // =========================
  // PATIENTS
  // =========================

  Future<int> insertPatient(Map<String, dynamic> data) async {
    final db = await database;

    data['sync_status'] = 'pending';
    data['updated_at'] = DateTime.now().toIso8601String();
    data['created_at'] ??= DateTime.now().toIso8601String();

data['queue_status'] ??= 'Waiting';
data['queue_date'] ??=
    DateTime.now().toIso8601String();
    return db.insert('patients', data);
  }

  Future<int> updatePatient(int id, Map<String, dynamic> data) async {
    final db = await database;

    data['sync_status'] = 'pending';
    data['updated_at'] = DateTime.now().toIso8601String();

    return db.update(
      'patients',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getPatients() async {
    final db = await database;
    return db.query('patients', orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> getPatientsByDoctor(int doctorId) async {
    final db = await database;

    return db.query(
      'patients',
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
      orderBy: 'id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> searchPatients(String query) async {
    final db = await database;
    final q = '%$query%';

    return db.query(
      'patients',
      where: 'patient_name LIKE ? OR phone_number LIKE ?',
      whereArgs: [q, q],
      orderBy: 'id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> searchPatientsByDoctor(
    int doctorId,
    String query,
  ) async {
    final db = await database;
    final q = '%$query%';

    return db.query(
      'patients',
      where: 'doctor_id = ? AND (patient_name LIKE ? OR phone_number LIKE ?)',
      whereArgs: [doctorId, q, q],
      orderBy: 'id DESC',
    );
  }

  Future<int> deletePatient(int id) async {
    final db = await database;

    return db.delete(
      'patients',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getPatientById(int id) async {
    final db = await database;

    final result = await db.query(
      'patients',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>?> getPatientByPhone(String phone) async {
    final db = await database;

    final result = await db.query(
      'patients',
      where: 'phone_number = ?',
      whereArgs: [phone],
      limit: 1,
    );

    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>?> getPatientByPhoneAndDoctor(
    String phone,
    int doctorId,
  ) async {
    final db = await database;

    final result = await db.query(
      'patients',
      where: 'phone_number = ? AND doctor_id = ?',
      whereArgs: [phone, doctorId],
      limit: 1,
    );

    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getPatientsByBasicDetailsWithoutPhone({
    required String patientName,
    required String patientAge,
    required String patientGender,
  }) async {
    final db = await database;

    return db.query(
      'patients',
      where:
          'patient_name = ? AND patient_age = ? AND patient_gender = ? AND (phone_number IS NULL OR phone_number = "")',
      whereArgs: [patientName, patientAge, patientGender],
    );
  }

  Future<List<Map<String, dynamic>>> getPendingPatients() async {
    final db = await database;

    return db.query(
      'patients',
      where: 'sync_status = ? OR sync_status = ?',
      whereArgs: ['pending', 'failed'],
      orderBy: 'id ASC',
    );
  }

  Future<void> markPatientSynced(int localId, int serverId) async {
    final db = await database;

    await db.update(
      'patients',
      {
        'sync_status': 'synced',
        'server_id': serverId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> markPatientSyncFailed(int localId) async {
    final db = await database;

    await db.update(
      'patients',
      {
        'sync_status': 'failed',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // =========================
  // PRESCRIPTIONS
  // =========================

  Future<void> insertPrescriptionItems(
  int prescriptionId,
  List<Map<String, dynamic>> items,
) async {
  final db = await database;

  for (final item in items) {
    await db.insert('prescription_items', {
      'prescription_id': prescriptionId,
      'medicine_name': item['medicine_name'] ?? item['medicineName'] ?? '',
      'dosage': item['dosage'] ?? '',
      'frequency': item['frequency'] ?? '',
      'duration': item['duration'] ?? '',
      'instructions': item['instructions'] ?? '',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}

Future<void> replacePrescriptionItems(
  int prescriptionId,
  List<Map<String, dynamic>> items,
) async {
  final db = await database;

  await db.delete(
    'prescription_items',
    where: 'prescription_id = ?',
    whereArgs: [prescriptionId],
  );

  await insertPrescriptionItems(prescriptionId, items);
}

Future<List<Map<String, dynamic>>> getPrescriptionItems(
  int prescriptionId,
) async {
  final db = await database;

  return db.query(
    'prescription_items',
    where: 'prescription_id = ?',
    whereArgs: [prescriptionId],
    orderBy: 'id ASC',
  );
}

Future<void> deletePrescriptionItems(int prescriptionId) async {
  final db = await database;

  await db.delete(
    'prescription_items',
    where: 'prescription_id = ?',
    whereArgs: [prescriptionId],
  );
}

  Future<int> insertPrescription(Map<String, dynamic> data) async {
    final db = await database;

    data['sync_status'] = 'pending';
    data['updated_at'] = DateTime.now().toIso8601String();

    return db.insert('prescriptions', data);
  }

  Future<int> updatePrescription(int id, Map<String, dynamic> data) async {
    final db = await database;

    data['sync_status'] = 'pending';
    data['updated_at'] = DateTime.now().toIso8601String();

    return db.update(
      'prescriptions',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getPrescriptions() async {
    final db = await database;

    return db.query(
      'prescriptions',
      orderBy: 'id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPrescriptionsByDoctor(
    int doctorId,
  ) async {
    final db = await database;

    return db.query(
      'prescriptions',
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
      orderBy: 'id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPrescriptionsByPatientId(
    int patientId,
  ) async {
    final db = await database;

    return db.query(
      'prescriptions',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPrescriptionsByPatientAndDoctor(
    int patientId,
    int doctorId,
  ) async {
    final db = await database;

    return db.query(
      'prescriptions',
      where: 'patient_id = ? AND doctor_id = ?',
      whereArgs: [patientId, doctorId],
      orderBy: 'id DESC',
    );
  }

  Future<Map<String, dynamic>?> getPrescriptionByNo(String rxNo) async {
    final db = await database;

    final result = await db.query(
      'prescriptions',
      where: 'prescription_no = ?',
      whereArgs: [rxNo],
      limit: 1,
    );

    return result.isNotEmpty ? result.first : null;
  }

  Future<int> deletePrescription(int id) async {
    final db = await database;

    return db.delete(
      'prescriptions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getPendingPrescriptions() async {
    final db = await database;

    return db.query(
      'prescriptions',
      where: 'sync_status = ? OR sync_status = ?',
      whereArgs: ['pending', 'failed'],
      orderBy: 'id ASC',
    );
  }

  Future<void> markPrescriptionSynced(
    int localId,
    int serverId,
    int serverPatientId,
  ) async {
    final db = await database;

    await db.update(
      'prescriptions',
      {
        'sync_status': 'synced',
        'server_id': serverId,
        'server_patient_id': serverPatientId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> markPrescriptionSyncFailed(int localId) async {
    final db = await database;

    await db.update(
      'prescriptions',
      {
        'sync_status': 'failed',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> attachServerPatientIdToLocalPrescription({
    required int localPrescriptionId,
    required int serverPatientId,
  }) async {
    final db = await database;

    await db.update(
      'prescriptions',
      {
        'server_patient_id': serverPatientId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localPrescriptionId],
    );
  }

  // =========================
  // LEGACY FIX
  // =========================

  

  // =========================
  // TEMPLATES
  // =========================

  Future<int> insertTemplate(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('templates', data);
  }

  Future<List<Map<String, dynamic>>> getTemplates() async {
    final db = await database;
    return db.query('templates', orderBy: 'is_favorite DESC, id DESC');
  }

  Future<int> updateTemplate(int id, Map<String, dynamic> data) async {
    final db = await database;

    return db.update(
      'templates',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTemplate(int id) async {
    final db = await database;

    return db.delete(
      'templates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =========================
  // MEDICINES
  // =========================

  Future<int> insertMedicine(Map<String, dynamic> data) async {
    final db = await database;

    data['sync_status'] ??= 'pending';
    data['created_at'] ??= DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    data['is_favorite'] ??= 0;

    return db.insert('medicines', data);
  }

  Future<int> updateMedicine(int id, Map<String, dynamic> data) async {
    final db = await database;

    data['sync_status'] = 'pending';
    data['updated_at'] = DateTime.now().toIso8601String();

    return db.update(
      'medicines',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteMedicine(int id) async {
  final db = await database;

  return db.update(
    'medicines',
    {
      'is_deleted': 1,
      'sync_status': 'pending',
      'updated_at': DateTime.now().toIso8601String(),
    },
    where: 'id = ?',
    whereArgs: [id],
  );
}

Future<int> permanentlyDeleteMedicine(int id) async {
  final db = await database;

  return db.delete(
    'medicines',
    where: 'id = ?',
    whereArgs: [id],
  );
}

  Future<Map<String, dynamic>?> getMedicineById(int id) async {
    final db = await database;

    final result = await db.query(
      'medicines',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getMedicinesByDoctor(int doctorId) async {
  final db = await database;

  return db.query(
    'medicines',
    where: 'doctor_id = ? AND (is_deleted IS NULL OR is_deleted = 0)',
    whereArgs: [doctorId],
    orderBy: 'is_favorite DESC, medicine_name ASC',
  );
}

  Future<List<Map<String, dynamic>>> searchMedicinesByDoctor(
  int doctorId,
  String query,
) async {
  final db = await database;
  final q = '%$query%';

  return db.query(
    'medicines',
    where:
        'doctor_id = ? AND (is_deleted IS NULL OR is_deleted = 0) AND (medicine_name LIKE ? OR generic_name LIKE ? OR brand_name LIKE ? OR drug_group LIKE ?)',
    whereArgs: [doctorId, q, q, q, q],
    orderBy: 'is_favorite DESC, medicine_name ASC',
  );
}

  Future<List<Map<String, dynamic>>> getFavoriteMedicinesByDoctor(
  int doctorId,
) async {
  final db = await database;

  return db.query(
    'medicines',
    where:
        'doctor_id = ? AND is_favorite = ? AND (is_deleted IS NULL OR is_deleted = 0)',
    whereArgs: [doctorId, 1],
    orderBy: 'medicine_name ASC',
  );
}

  Future<void> toggleMedicineFavorite(int id, bool isFavorite) async {
    final db = await database;

    await db.update(
      'medicines',
      {
        'is_favorite': isFavorite ? 1 : 0,
        'sync_status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getPendingMedicines() async {
    final db = await database;

    return db.query(
      'medicines',
      where: 'sync_status = ? OR sync_status = ?',
      whereArgs: ['pending', 'failed'],
      orderBy: 'id ASC',
    );
  }

  Future<void> markMedicineSynced(int localId, int serverId) async {
    final db = await database;

    await db.update(
      'medicines',
      {
        'server_id': serverId,
        'sync_status': 'synced',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> markMedicineSyncFailed(int localId) async {
    final db = await database;

    await db.update(
      'medicines',
      {
        'sync_status': 'failed',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> upsertMedicineFromServer({
    required int doctorId,
    required int serverId,
    required String medicineName,
    String? genericName,
    String? brandName,
    String? drugGroup,
    String? doseForm,
    String? strength,
    int isFavorite = 0,
    String? createdAt,
    String? updatedAt,
  }) async {
    final db = await database;

    final existing = await db.query(
      'medicines',
      where: 'server_id = ? AND doctor_id = ?',
      whereArgs: [serverId, doctorId],
      limit: 1,
    );

    final data = {
      'server_id': serverId,
      'doctor_id': doctorId,
      'medicine_name': medicineName,
      'generic_name': genericName ?? '',
      'brand_name': brandName ?? '',
      'drug_group': drugGroup ?? '',
      'dose_form': doseForm ?? '',
      'strength': strength ?? '',
      'is_favorite': isFavorite,
      'sync_status': 'synced',
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    };

    if (existing.isEmpty) {
      await db.insert('medicines', data);
    } else {
      await db.update(
        'medicines',
        data,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  bool hasDrugGroupAllergy({
    required String patientAllergies,
    required String medicineDrugGroup,
  }) {
    final allergies = patientAllergies.toLowerCase();
    final group = medicineDrugGroup.toLowerCase().trim();

    if (group.isEmpty) return false;

    return allergies.contains(group);
  }

  

 

  // =========================
  // CUSTOM INSTRUCTIONS
  // =========================

  Future<int> insertCustomInstruction(Map<String, dynamic> data) async {
    final db = await database;

    data['sync_status'] ??= 'pending';
    data['usage_count'] ??= 0;
    data['created_at'] ??= DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();

    return db.insert('custom_instructions', data);
  }

  Future<List<Map<String, dynamic>>> getCustomInstructionsByDoctor(
    int doctorId,
  ) async {
    final db = await database;

    return db.query(
      'custom_instructions',
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
      orderBy: 'usage_count DESC, instruction_text ASC',
    );
  }

  Future<void> incrementCustomInstructionUsage(int id) async {
    final db = await database;

    await db.rawUpdate(
      '''
      UPDATE custom_instructions
      SET usage_count = usage_count + 1,
          updated_at = ?
      WHERE id = ?
      ''',
      [DateTime.now().toIso8601String(), id],
    );
  }

  Future<List<Map<String, dynamic>>> getPendingCustomInstructions() async {
    final db = await database;

    return db.query(
      'custom_instructions',
      where: 'sync_status = ? OR sync_status = ?',
      whereArgs: ['pending', 'failed'],
      orderBy: 'id ASC',
    );
  }

  Future<void> markCustomInstructionSynced(int localId, int serverId) async {
    final db = await database;

    await db.update(
      'custom_instructions',
      {
        'server_id': serverId,
        'sync_status': 'synced',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> markCustomInstructionSyncFailed(int localId) async {
    final db = await database;

    await db.update(
      'custom_instructions',
      {
        'sync_status': 'failed',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> _createIndexes(Database db) async {
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_patients_doctor_id ON patients(doctor_id)',
  );

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_patients_doctor_name ON patients(doctor_id, patient_name)',
  );

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_patients_doctor_phone ON patients(doctor_id, phone_number)',
  );

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_patients_queue ON patients(doctor_id, queue_status, queue_date)',
  );

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_prescriptions_doctor_id ON prescriptions(doctor_id)',
  );

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_prescriptions_patient_doctor ON prescriptions(patient_id, doctor_id)',
  );

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_prescriptions_date ON prescriptions(doctor_id, prescription_date)',
  );

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_prescriptions_followup ON prescriptions(doctor_id, follow_up_status, follow_up_date)',
  );

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_prescriptions_sync ON prescriptions(sync_status)',
  );

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_medicines_doctor_name ON medicines(doctor_id, medicine_name)',
  );

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_medicines_doctor_favorite ON medicines(doctor_id, is_favorite, medicine_name)',
  );

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_medicines_sync ON medicines(sync_status)',
  );

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_custom_instructions_doctor ON custom_instructions(doctor_id, usage_count)',
  );

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_prescription_items_prescription ON prescription_items(prescription_id)',
  );
}

Future<List<Map<String, dynamic>>> getPatientsByDoctorPaged(
  int doctorId, {
  int limit = 30,
  int offset = 0,
}) async {
  final db = await database;

  return db.query(
    'patients',
    where: 'doctor_id = ?',
    whereArgs: [doctorId],
    orderBy: 'id DESC',
    limit: limit,
    offset: offset,
  );
}

Future<List<Map<String, dynamic>>> searchPatientsByDoctorPaged(
  int doctorId,
  String query, {
  int limit = 30,
  int offset = 0,
}) async {
  final db = await database;
  final q = '%${query.trim()}%';

  return db.query(
    'patients',
    where: 'doctor_id = ? AND (patient_name LIKE ? OR phone_number LIKE ?)',
    whereArgs: [doctorId, q, q],
    orderBy: 'id DESC',
    limit: limit,
    offset: offset,
  );
}

Future<List<Map<String, dynamic>>> getPrescriptionsByDoctorPaged(
  int doctorId, {
  int limit = 30,
  int offset = 0,
}) async {
  final db = await database;

  return db.query(
    'prescriptions',
    where: 'doctor_id = ?',
    whereArgs: [doctorId],
    orderBy: 'id DESC',
    limit: limit,
    offset: offset,
  );
}

Future<List<Map<String, dynamic>>> getMedicinesByDoctorPaged(
  int doctorId, {
  int limit = 50,
  int offset = 0,
}) async {
  final db = await database;

  return db.query(
    'medicines',
    where: 'doctor_id = ? AND (is_deleted IS NULL OR is_deleted = 0)',
    whereArgs: [doctorId],
    orderBy: 'is_favorite DESC, medicine_name ASC',
    limit: limit,
    offset: offset,
  );
}
Future<List<Map<String, dynamic>>> searchMedicinesByDoctorPaged(
  int doctorId,
  String query, {
  int limit = 50,
  int offset = 0,
}) async {
  final db = await database;
  final q = '%${query.trim()}%';

  return db.query(
    'medicines',
    where:
        'doctor_id = ? AND (is_deleted IS NULL OR is_deleted = 0) AND (medicine_name LIKE ? OR generic_name LIKE ? OR brand_name LIKE ? OR drug_group LIKE ?)',
    whereArgs: [doctorId, q, q, q, q],
    orderBy: 'is_favorite DESC, medicine_name ASC',
    limit: limit,
    offset: offset,
  );
}

  // =========================
  // DASHBOARD
  // =========================

  Future<int> getTodayPrescriptionCountByDoctor(int doctorId) async {
  final db = await database;
  final today = DateTime.now().toIso8601String().substring(0, 10);

  final result = await db.rawQuery(
    '''
    SELECT COUNT(*) as count
    FROM prescriptions
    WHERE doctor_id = ? AND prescription_date = ?
    ''',
    [doctorId, today],
  );

  return Sqflite.firstIntValue(result) ?? 0;
}

Future<int> getTodayPatientCountByDoctor(int doctorId) async {
  final db = await database;
  final today = DateTime.now().toIso8601String().substring(0, 10);

  final result = await db.rawQuery(
    '''
    SELECT COUNT(DISTINCT patient_id) as count
    FROM prescriptions
    WHERE doctor_id = ? AND prescription_date = ?
    ''',
    [doctorId, today],
  );

  return Sqflite.firstIntValue(result) ?? 0;
}

  Future<int> getTodayPrescriptionCount() async {
    final db = await database;
    final today = DateTime.now().toString().substring(0, 10);

    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM prescriptions
      WHERE prescription_date = ?
      ''',
      [today],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTodayPatientCount() async {
    final db = await database;
    final today = DateTime.now().toString().substring(0, 10);

    final result = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT patient_id) as count
      FROM prescriptions
      WHERE prescription_date = ?
      ''',
      [today],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getLast7DaysStats() async {
    final db = await database;

    return db.rawQuery('''
      SELECT prescription_date, COUNT(*) as count
      FROM prescriptions
      GROUP BY prescription_date
      ORDER BY prescription_date DESC
      LIMIT 7
    ''');
  }

  Future<List<Map<String, dynamic>>> getTopMedicines() async {
  final db = await database;

  final result = await db.rawQuery('''
    SELECT medicine_name as name, COUNT(*) as count
    FROM prescription_items
    WHERE medicine_name IS NOT NULL AND medicine_name != ''
    GROUP BY medicine_name
    ORDER BY count DESC
    LIMIT 5
  ''');

  return result;
}

  // =========================
  // SERVER UPSERT
  // =========================

  Future<void> upsertPatientFromServer({
    required int doctorId,
    required int serverId,
    required String patientName,
    required String patientAge,
    required String patientGender,
    String? phoneNumber,
    String? address,
    String? notes,
    String? updatedAt,
    String? createdAt,
  }) async {
    final db = await database;

    final existing = await db.query(
      'patients',
      where: 'server_id = ? AND doctor_id = ?',
      whereArgs: [serverId, doctorId],
      limit: 1,
    );

    final data = {
      'server_id': serverId,
      'doctor_id': doctorId,
      'patient_name': patientName,
      'patient_age': patientAge,
      'patient_gender': patientGender,
      'phone_number': phoneNumber,
      'address': address,
      'notes': notes,
      'sync_status': 'synced',
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };

    if (existing.isEmpty) {
      await db.insert('patients', data);
    } else {
      await db.update(
        'patients',
        data,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  Future<void> upsertPrescriptionFromServer({
    required int doctorId,
    required int serverId,
    required int serverPatientId,
    required String patientName,
    required String patientAge,
    required String patientGender,
    required String prescriptionNo,
    required String prescriptionDate,
    required String itemsText,
    String? complaint,
    String? diagnosis,
    String? visitNotes,
    String? updatedAt,
  }) async {
    final db = await database;

    final patient = await db.query(
      'patients',
      where: 'server_id = ? AND doctor_id = ?',
      whereArgs: [serverPatientId, doctorId],
      limit: 1,
    );

    if (patient.isEmpty) return;

    final localPatientId = patient.first['id'] as int;

    final existing = await db.query(
      'prescriptions',
      where: 'server_id = ? AND doctor_id = ?',
      whereArgs: [serverId, doctorId],
      limit: 1,
    );

    final data = {
      'server_id': serverId,
      'doctor_id': doctorId,
      'patient_id': localPatientId,
      'server_patient_id': serverPatientId,
      'patient_name': patientName,
      'patient_age': patientAge,
      'patient_gender': patientGender,
      'prescription_no': prescriptionNo,
      'prescription_date': prescriptionDate,
      'items_text': itemsText,
      'complaint': complaint,
      'diagnosis': diagnosis,
      'visit_notes': visitNotes,
      'sync_status': 'synced',
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    };

    if (existing.isEmpty) {
      await db.insert('prescriptions', data);
    } else {
      await db.update(
        'prescriptions',
        data,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  Future<void> assignOldLocalDataToDoctor(int doctorId) async {
  final db = await database;

  await db.update(
    'patients',
    {'doctor_id': doctorId},
    where: 'doctor_id IS NULL OR doctor_id = 0',
  );

  await db.update(
    'medicines',
    {'doctor_id': doctorId},
    where: 'doctor_id IS NULL OR doctor_id = 0',
  );

  await db.update(
    'prescriptions',
    {'doctor_id': doctorId},
    where: 'doctor_id IS NULL OR doctor_id = 0',
  );
}

// =========================
// CUSTOM CLINICAL CHIPS
// =========================

Future<void> deleteClinicalChip({
  required int doctorId,
  required String category,
  required String value,
}) async {
  final db = await database;

  await db.delete(
    'custom_clinical_chips',
    where: 'doctor_id = ? AND category = ? AND value = ?',
    whereArgs: [doctorId, category, value],
  );
}

Future<void> insertClinicalChip({
  required int doctorId,
  required String category,
  required String value,
}) async {
  final db = await database;

  final existing = await db.query(
    'custom_clinical_chips',
    where: 'doctor_id = ? AND category = ? AND value = ?',
    whereArgs: [doctorId, category, value],
    limit: 1,
  );

  if (existing.isNotEmpty) return;

  await db.insert(
    'custom_clinical_chips',
    {
      'doctor_id': doctorId,
      'category': category,
      'value': value,
      'created_at': DateTime.now().toIso8601String(),
    },
  );
}

Future<List<String>> getClinicalChips({
  required int doctorId,
  required String category,
}) async {
  final db = await database;

  final result = await db.query(
    'custom_clinical_chips',
    where: 'doctor_id = ? AND category = ?',
    whereArgs: [doctorId, category],
    orderBy: 'value ASC',
  );

  return result.map((e) => e['value'].toString()).toList();
}
Future<Map<String, dynamic>?> getLastPrescriptionByPatient({
  required int patientId,
  required int doctorId,
}) async {
  final db = await database;

  final result = await db.query(
    'prescriptions',
    where: 'patient_id = ? AND doctor_id = ?',
    whereArgs: [patientId, doctorId],
    orderBy: 'prescription_date DESC, id DESC',
    limit: 1,
  );

  return result.isNotEmpty ? result.first : null;
}

Future<List<Map<String, dynamic>>> getLastPrescriptionMedicines(
  int prescriptionId,
) async {
  final db = await database;

  return db.query(
    'prescription_items',
    where: 'prescription_id = ?',
    whereArgs: [prescriptionId],
    orderBy: 'id ASC',
  );
}

Future<List<Map<String, dynamic>>>
    getTodayFollowUps({
  required int doctorId,
}) async {
  final db = await database;

  final today =
      DateTime.now()
          .toIso8601String()
          .substring(0, 10);

  return await db.query(
  'prescriptions',
  where:
      'doctor_id = ? AND follow_up_date LIKE ? AND follow_up_status = ?',
  whereArgs: [
    doctorId,
    '$today%',
    'pending',
  ],
  orderBy: 'follow_up_date ASC',
);
}
Future<List<Map<String, dynamic>>>
    getUpcomingFollowUps({
  required int doctorId,
}) async {
  final db = await database;

  final today =
      DateTime.now()
          .toIso8601String()
          .substring(0, 10);

  return db.query(
    'prescriptions',
    where:
        'doctor_id = ? AND follow_up_date > ? AND follow_up_status = ?',
    whereArgs: [
      doctorId,
      today,
      'pending',
    ],
    orderBy: 'follow_up_date ASC',
  );
}

Future<List<Map<String, dynamic>>>
    getOverdueFollowUps({
  required int doctorId,
}) async {
  final db = await database;

  final today =
      DateTime.now()
          .toIso8601String()
          .substring(0, 10);

  return db.query(
    'prescriptions',
    where:
        'doctor_id = ? AND follow_up_date < ? AND follow_up_status = ?',
    whereArgs: [
      doctorId,
      today,
      'pending',
    ],
    orderBy: 'follow_up_date ASC',
  );
}

Future<List<Map<String, dynamic>>>
    getCompletedFollowUps({
  required int doctorId,
}) async {
  final db = await database;

  return db.query(
    'prescriptions',
    where:
        'doctor_id = ? AND follow_up_status = ?',
    whereArgs: [
      doctorId,
      'completed',
    ],
    orderBy: 'follow_up_date DESC',
    limit: 50,
  );
}

Future<void> completeFollowUp(
  int prescriptionId,
) async {
  final db = await database;

  await db.update(
    'prescriptions',
    {
      'follow_up_status':
          'completed',
    },
    where: 'id = ?',
    whereArgs: [prescriptionId],
  );
}
}