import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/auth/data/doctor_session.dart';

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
      version: 38,
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
queue_date TEXT,
is_deleted INTEGER DEFAULT 0,
server_version INTEGER DEFAULT 0,
conflict_server_json TEXT,
client_request_id TEXT
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
,
is_deleted INTEGER DEFAULT 0,
server_version INTEGER DEFAULT 0,
conflict_server_json TEXT
      )
    ''');

    await db.execute('''
  CREATE TABLE prescription_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    prescription_id INTEGER,
    medicine_id INTEGER,
    medicine_name TEXT,
    dosage TEXT,
    frequency TEXT,
    duration TEXT,
    instructions TEXT,
    created_at TEXT,
    prescription_only INTEGER DEFAULT 0,
unit_price REAL DEFAULT 0,
quantity REAL DEFAULT 1,
line_total REAL DEFAULT 0
  )
''');

    await db.execute('''
  CREATE TABLE prescription_bills (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    server_id INTEGER,

    doctor_id INTEGER,
    patient_id INTEGER,
    prescription_id INTEGER,

    prescription_no TEXT,

    consultation_fee REAL DEFAULT 0,
    medicine_charges REAL DEFAULT 0,
    other_charges REAL DEFAULT 0,
    discount_amount REAL DEFAULT 0,

    total_amount REAL DEFAULT 0,
    paid_amount REAL DEFAULT 0,
    balance_amount REAL DEFAULT 0,

    payment_method TEXT,
    payment_status TEXT,

    notes TEXT,

    sync_status TEXT DEFAULT 'pending',
    server_version INTEGER DEFAULT 0,
    is_deleted INTEGER DEFAULT 0,

    created_at TEXT,
    updated_at TEXT
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
        custom_medicine_name TEXT,
custom_generic_name TEXT,
custom_brand_name TEXT,
custom_drug_group TEXT,
custom_medicine_type TEXT,
        generic_name TEXT,
        brand_name TEXT,
        drug_group TEXT,
        dose_form TEXT,
        strength TEXT,

custom_dosage TEXT,

custom_frequency TEXT,

custom_duration TEXT,

custom_instructions TEXT,

selling_price REAL DEFAULT 0,

cost_price REAL DEFAULT 0,

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
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0
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
    await _createDuplicateProtectionIndexes(db);
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
      await db
          .execute('ALTER TABLE prescriptions ADD COLUMN server_id INTEGER');
    } catch (_) {}

    try {
      await db
          .execute('ALTER TABLE prescriptions ADD COLUMN doctor_id INTEGER');
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

    if (oldVersion < 27) {
      await db.execute('''
    CREATE TABLE IF NOT EXISTS prescription_bills (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id INTEGER,

      doctor_id INTEGER,
      patient_id INTEGER,
      prescription_id INTEGER,

      prescription_no TEXT,

      consultation_fee REAL DEFAULT 0,
      medicine_charges REAL DEFAULT 0,
      other_charges REAL DEFAULT 0,
      discount_amount REAL DEFAULT 0,

      total_amount REAL DEFAULT 0,
      paid_amount REAL DEFAULT 0,
      balance_amount REAL DEFAULT 0,

      payment_method TEXT,
      payment_status TEXT,

      notes TEXT,

      sync_status TEXT DEFAULT 'pending',

      created_at TEXT,
      updated_at TEXT
    )
  ''');
    }

    if (oldVersion < 28) {
      try {
        await db.execute(
          'ALTER TABLE prescription_items ADD COLUMN prescription_only INTEGER DEFAULT 0',
        );
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE prescription_items ADD COLUMN unit_price REAL DEFAULT 0',
        );
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE prescription_items ADD COLUMN quantity REAL DEFAULT 1',
        );
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE prescription_items ADD COLUMN line_total REAL DEFAULT 0',
        );
      } catch (_) {}
    }

    if (oldVersion < 32) {
      await db.execute(
        'ALTER TABLE patients ADD COLUMN is_deleted INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE prescriptions ADD COLUMN is_deleted INTEGER DEFAULT 0',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_patients_delete_sync '
        'ON patients(doctor_id, is_deleted, sync_status)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_prescriptions_delete_sync '
        'ON prescriptions(doctor_id, is_deleted, sync_status)',
      );
    }

    if (oldVersion < 33) {
      await db.execute(
        'ALTER TABLE prescription_bills '
        'ADD COLUMN server_version INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE prescription_bills '
        'ADD COLUMN is_deleted INTEGER DEFAULT 0',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bills_sync '
        'ON prescription_bills(doctor_id, is_deleted, sync_status)',
      );
    }

    if (oldVersion < 34) {
      await db.execute(
        'ALTER TABLE patients '
        'ADD COLUMN server_version INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE patients ADD COLUMN conflict_server_json TEXT',
      );
      await db.execute(
        'ALTER TABLE prescriptions '
        'ADD COLUMN server_version INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE prescriptions ADD COLUMN conflict_server_json TEXT',
      );
    }

    if (oldVersion < 35) {
      await db.execute(
        'ALTER TABLE prescription_items ADD COLUMN medicine_id INTEGER',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_prescription_items_medicine '
        'ON prescription_items(medicine_id)',
      );
    }

    if (oldVersion < 36) {
      try {
        await db.execute(
          'ALTER TABLE custom_instructions '
          'ADD COLUMN is_deleted INTEGER DEFAULT 0',
        );
      } catch (_) {}

      await db.execute(
        "UPDATE templates SET name = trim(name) WHERE name IS NOT NULL",
      );
      await db.execute('''
        DELETE FROM templates
        WHERE id NOT IN (
          SELECT MAX(id)
          FROM templates
          WHERE trim(COALESCE(name, '')) <> ''
          GROUP BY lower(trim(name))
        )
        AND trim(COALESCE(name, '')) <> ''
      ''');

      await db.execute('''
        UPDATE custom_instructions
        SET instruction_text = trim(instruction_text)
      ''');
      await db.execute('''
        UPDATE custom_instructions
        SET usage_count = (
          SELECT SUM(other.usage_count)
          FROM custom_instructions other
          WHERE other.doctor_id = custom_instructions.doctor_id
            AND lower(trim(other.instruction_text)) =
                lower(trim(custom_instructions.instruction_text))
            AND COALESCE(other.is_deleted, 0) = 0
        )
        WHERE id IN (
          SELECT MAX(id)
          FROM custom_instructions
          WHERE COALESCE(is_deleted, 0) = 0
          GROUP BY doctor_id, lower(trim(instruction_text))
        )
      ''');
      await db.execute('''
        UPDATE custom_instructions
        SET is_deleted = 1
        WHERE COALESCE(is_deleted, 0) = 0
          AND id NOT IN (
            SELECT MAX(id)
            FROM custom_instructions
            WHERE COALESCE(is_deleted, 0) = 0
            GROUP BY doctor_id, lower(trim(instruction_text))
          )
      ''');

      await _createIndexes(db);
      await _createDuplicateProtectionIndexes(db);
    }

    if (oldVersion < 29) {
      try {
        await db.execute(
          'ALTER TABLE medicines ADD COLUMN selling_price REAL DEFAULT 0',
        );
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE medicines ADD COLUMN cost_price REAL DEFAULT 0',
        );
      } catch (_) {}
    }

    if (oldVersion < 30) {
      try {
        await db.execute(
          'ALTER TABLE medicines ADD COLUMN custom_dosage TEXT',
        );
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE medicines ADD COLUMN custom_frequency TEXT',
        );
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE medicines ADD COLUMN custom_duration TEXT',
        );
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE medicines ADD COLUMN custom_instructions TEXT',
        );
      } catch (_) {}
    }

    if (oldVersion < 31) {
      try {
        await db.execute(
          'ALTER TABLE medicines ADD COLUMN custom_medicine_name TEXT',
        );
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE medicines ADD COLUMN custom_generic_name TEXT',
        );
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE medicines ADD COLUMN custom_brand_name TEXT',
        );
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE medicines ADD COLUMN custom_drug_group TEXT',
        );
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE medicines ADD COLUMN custom_medicine_type TEXT',
        );
      } catch (_) {}
    }

    if (oldVersion < 37) {
      try {
        await db.execute(
          'ALTER TABLE patients ADD COLUMN client_request_id TEXT',
        );
      } catch (_) {}
    }

    if (oldVersion < 38) {
      await _removeLegacyDoctorPasswordColumn(db);
    }
  }

  Future<void> _removeLegacyDoctorPasswordColumn(Database db) async {
    await db.execute('ALTER TABLE doctors RENAME TO doctors_legacy');
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
        biometric_enabled INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'pending',
        updated_at TEXT,
        created_at TEXT,
        signature_path TEXT
      )
    ''');
    await db.execute('''
      INSERT INTO doctors (
        id, server_id, doctor_name, contact_number, email, city,
        specialization, role, medical_center_name, clinic_address,
        qualifications, profession, slmc_reg_no, affiliation,
        biometric_enabled, sync_status, updated_at, created_at, signature_path
      )
      SELECT
        id, server_id, doctor_name, contact_number, email, city,
        specialization, role, medical_center_name, clinic_address,
        qualifications, profession, slmc_reg_no, affiliation,
        biometric_enabled, sync_status, updated_at, created_at, signature_path
      FROM doctors_legacy
    ''');
    await db.execute('DROP TABLE doctors_legacy');
    await _createIndexes(db);
  }

  // =========================
  // DOCTORS
  // =========================

  Future<int> insertDoctor(Map<String, dynamic> data) async {
    final db = await database;

    final safeData = Map<String, dynamic>.from(data)..remove('password');

    safeData['sync_status'] ??= 'pending';
    safeData['updated_at'] ??= DateTime.now().toIso8601String();
    safeData['created_at'] ??= DateTime.now().toIso8601String();

    safeData['qualifications'] ??= '';
    safeData['profession'] ??= '';
    safeData['slmc_reg_no'] ??= '';
    safeData['affiliation'] ??= '';
    safeData['signature_path'] ??= '';

    return db.insert('doctors', safeData);
  }

  Future<int> updateDoctor(
    int id,
    Map<String, dynamic> data,
  ) async {
    final db = await database;

    final safeData = Map<String, dynamic>.from(data)..remove('password');

    safeData['updated_at'] = DateTime.now().toIso8601String();

    return db.update(
      'doctors',
      safeData,
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
    data['queue_date'] ??= DateTime.now().toIso8601String();
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
    return db.query(
      'patients',
      where: 'is_deleted = 0',
      orderBy: 'id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPatientsByDoctor(int doctorId) async {
    final db = await database;

    return db.query(
      'patients',
      where: 'doctor_id = ? AND is_deleted = 0',
      whereArgs: [doctorId],
      orderBy: 'id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> searchPatients(String query) async {
    final db = await database;
    final q = '%$query%';

    return db.query(
      'patients',
      where: 'is_deleted = 0 AND (patient_name LIKE ? OR phone_number LIKE ?)',
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
      where:
          'doctor_id = ? AND is_deleted = 0 AND (patient_name LIKE ? OR phone_number LIKE ?)',
      whereArgs: [doctorId, q, q],
      orderBy: 'id DESC',
    );
  }

  Future<int> deletePatient(int id) async {
    final db = await database;
    final rows = await db.query(
      'patients',
      columns: ['server_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return 0;

    final serverId = rows.first['server_id'] as int?;
    if (serverId == null || serverId <= 0) {
      return db.delete('patients', where: 'id = ?', whereArgs: [id]);
    }

    return db.update(
      'patients',
      {
        'is_deleted': 1,
        'sync_status': 'pending',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getPatientById(int id) async {
    final db = await database;

    final result = await db.query(
      'patients',
      where: 'id = ? AND is_deleted = 0',
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

  Future<void> markPatientSynced(
    int localId,
    int serverId,
    int serverVersion,
  ) async {
    final db = await database;

    await db.update(
      'patients',
      {
        'sync_status': 'synced',
        'server_id': serverId,
        'server_version': serverVersion,
        'conflict_server_json': null,
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

  Future<void> markPatientSyncConflict(
    int localId,
    String message,
  ) async {
    final db = await database;
    await db.update(
      'patients',
      {
        'sync_status': 'conflict',
        'is_deleted': 0,
        'conflict_server_json': jsonEncode({'message': message}),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> removeSyncedPatientTombstone(int localId) async {
    final db = await database;
    await db.delete('patients', where: 'id = ?', whereArgs: [localId]);
  }

  Future<void> markPatientDeletedFromServer({
    required int doctorId,
    required int serverId,
  }) async {
    final db = await database;
    await db.delete(
      'patients',
      where: 'doctor_id = ? AND server_id = ?',
      whereArgs: [doctorId, serverId],
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
        'medicine_id': item['medicine_id'] ?? item['medicineId'],
        'medicine_name': item['medicine_name'] ?? item['medicineName'] ?? '',
        'dosage': item['dosage'] ?? '',
        'frequency': item['frequency'] ?? '',
        'duration': item['duration'] ?? '',
        'instructions': item['instructions'] ?? '',
        'created_at': DateTime.now().toIso8601String(),
        'prescription_only':
            item['prescription_only'] ?? item['prescriptionOnly'] ?? 0,
        'unit_price': item['unit_price'] ?? item['unitPrice'] ?? 0,
        'quantity': item['quantity'] ?? 1,
        'line_total': item['line_total'] ?? item['lineTotal'] ?? 0,
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

    final itemsText = items.map((item) {
      return '${item['medicine_name'] ?? item['medicineName'] ?? ''} | '
          '${item['dosage'] ?? ''} | '
          '${item['frequency'] ?? ''} | '
          '${item['duration'] ?? ''} | '
          '${item['instructions'] ?? ''}';
    }).join('\n');

    await db.update(
      'prescriptions',
      {
        'items_text': itemsText,
        'sync_status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [prescriptionId],
    );
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

    return db.transaction((txn) async {
      final doctorId = data['doctor_id'];
      final prescriptionNo = data['prescription_no']?.toString().trim() ?? '';
      if (doctorId != null && prescriptionNo.isNotEmpty) {
        final existing = await txn.query(
          'prescriptions',
          columns: ['id'],
          where: 'doctor_id = ? AND prescription_no = ? AND is_deleted = 0',
          whereArgs: [doctorId, prescriptionNo],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          final id = existing.first['id'] as int;
          await txn.update(
            'prescriptions',
            data,
            where: 'id = ?',
            whereArgs: [id],
          );
          return id;
        }
      }
      return txn.insert('prescriptions', data);
    });
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
      where: 'is_deleted = 0',
      orderBy: 'id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPrescriptionsByDoctor(
    int doctorId,
  ) async {
    final db = await database;

    return db.query(
      'prescriptions',
      where: 'doctor_id = ? AND is_deleted = 0',
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
      where: 'patient_id = ? AND is_deleted = 0',
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
      where: 'patient_id = ? AND doctor_id = ? AND is_deleted = 0',
      whereArgs: [patientId, doctorId],
      orderBy: 'id DESC',
    );
  }

  Future<Map<String, dynamic>?> getPrescriptionByNo(String rxNo) async {
    final db = await database;
    final doctorId = await DoctorSession.getActiveDoctorIdForData();

    if (doctorId == null || doctorId <= 0) return null;

    final result = await db.query(
      'prescriptions',
      where: 'prescription_no = ? AND doctor_id = ? AND is_deleted = 0',
      whereArgs: [rxNo, doctorId],
      limit: 1,
    );

    return result.isNotEmpty ? result.first : null;
  }

  Future<int> getLastPrescriptionSequence({
    required int doctorId,
    required int year,
  }) async {
    final db = await database;
    final prefix = '$year-';

    final rows = await db.query(
      'prescriptions',
      columns: ['prescription_no'],
      where: 'doctor_id = ? AND prescription_no LIKE ?',
      whereArgs: [doctorId, '$prefix%'],
    );

    var maximum = 0;

    for (final row in rows) {
      final rxNo = row['prescription_no']?.toString() ?? '';
      if (!rxNo.startsWith(prefix)) continue;

      final sequence = int.tryParse(rxNo.substring(prefix.length));
      if (sequence != null && sequence > maximum) {
        maximum = sequence;
      }
    }

    return maximum;
  }

  Future<int> deletePrescription(int id) async {
    final db = await database;
    final rows = await db.query(
      'prescriptions',
      columns: ['server_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return 0;

    final serverId = rows.first['server_id'] as int?;
    if (serverId == null || serverId <= 0) {
      await db.delete(
        'prescription_items',
        where: 'prescription_id = ?',
        whereArgs: [id],
      );
      return db.delete('prescriptions', where: 'id = ?', whereArgs: [id]);
    }

    return db.update(
      'prescriptions',
      {
        'is_deleted': 1,
        'sync_status': 'pending',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
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
    int serverVersion,
  ) async {
    final db = await database;

    await db.update(
      'prescriptions',
      {
        'sync_status': 'synced',
        'server_id': serverId,
        'server_patient_id': serverPatientId,
        'server_version': serverVersion,
        'conflict_server_json': null,
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

  Future<void> markPrescriptionSyncConflict(
    int localId,
    String message,
  ) async {
    final db = await database;
    await db.update(
      'prescriptions',
      {
        'sync_status': 'conflict',
        'is_deleted': 0,
        'conflict_server_json': jsonEncode({'message': message}),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> removeSyncedPrescriptionTombstone(int localId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'prescription_items',
        where: 'prescription_id = ?',
        whereArgs: [localId],
      );
      await txn.delete(
        'prescriptions',
        where: 'id = ?',
        whereArgs: [localId],
      );
    });
  }

  Future<void> markPrescriptionDeletedFromServer({
    required int doctorId,
    required int serverId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'prescriptions',
        columns: ['id'],
        where: 'doctor_id = ? AND server_id = ?',
        whereArgs: [doctorId, serverId],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final localId = rows.first['id'] as int;
      await txn.delete(
        'prescription_items',
        where: 'prescription_id = ?',
        whereArgs: [localId],
      );
      await txn.delete(
        'prescriptions',
        where: 'id = ?',
        whereArgs: [localId],
      );
    });
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
    data['name'] = data['name']?.toString().trim() ?? '';
    return db.insert('templates', data);
  }

  Future<List<Map<String, dynamic>>> getTemplates() async {
    final db = await database;
    return db.query('templates', orderBy: 'is_favorite DESC, id DESC');
  }

  Future<int> updateTemplate(int id, Map<String, dynamic> data) async {
    final db = await database;
    data['name'] = data['name']?.toString().trim() ?? '';

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
    String? customMedicineName,
    String? customGenericName,
    String? customBrandName,
    String? customDrugGroup,
    String? customMedicineType,
    String? customDosage,
    String? customFrequency,
    String? customDuration,
    String? customInstructions,
    double sellingPrice = 0,
    double costPrice = 0,
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
      'custom_medicine_name': customMedicineName ?? '',
      'custom_generic_name': customGenericName ?? '',
      'custom_brand_name': customBrandName ?? '',
      'custom_drug_group': customDrugGroup ?? '',
      'custom_medicine_type': customMedicineType ?? '',
      'generic_name': genericName ?? '',
      'brand_name': brandName ?? '',
      'drug_group': drugGroup ?? '',
      'dose_form': doseForm ?? '',
      'strength': strength ?? '',
      'custom_dosage': customDosage ?? '',
      'custom_frequency': customFrequency ?? '',
      'custom_duration': customDuration ?? '',
      'custom_instructions': customInstructions ?? '',
      'selling_price': sellingPrice,
      'cost_price': costPrice,
      'is_favorite': isFavorite,
      'sync_status': 'synced',
      'is_deleted': 0,
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

  Future<void> markMedicineDeletedFromServer({
    required int doctorId,
    required int serverId,
    String? updatedAt,
  }) async {
    final db = await database;

    await db.update(
      'medicines',
      {
        'is_deleted': 1,
        'sync_status': 'synced',
        'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
      },
      where: 'doctor_id = ? AND server_id = ?',
      whereArgs: [doctorId, serverId],
    );
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

    data['instruction_text'] =
        data['instruction_text']?.toString().trim() ?? '';

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
      where: 'doctor_id = ? AND is_deleted = 0',
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
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_prescription_items_medicine ON prescription_items(medicine_id)',
    );
  }

  Future<void> _createDuplicateProtectionIndexes(Database db) async {
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_templates_unique_name '
      'ON templates(lower(trim(name))) '
      "WHERE trim(COALESCE(name, '')) <> ''",
    );

    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_custom_instructions_unique_text '
      'ON custom_instructions(doctor_id, lower(trim(instruction_text))) '
      'WHERE COALESCE(is_deleted, 0) = 0',
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
      where: 'doctor_id = ? AND is_deleted = 0',
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
      where:
          'doctor_id = ? AND is_deleted = 0 AND (patient_name LIKE ? OR phone_number LIKE ?)',
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
      where: 'doctor_id = ? AND is_deleted = 0',
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
// PRESCRIPTION BILLS
// =========================

  Future<int> insertPrescriptionBill(
    Map<String, dynamic> data,
  ) async {
    final db = await database;

    data['sync_status'] ??= 'pending';
    data['created_at'] ??= DateTime.now().toIso8601String();

    data['updated_at'] = DateTime.now().toIso8601String();

    return db.transaction((txn) async {
      List<Map<String, Object?>> existing = const [];
      final prescriptionId = data['prescription_id'];
      if (prescriptionId != null) {
        existing = await txn.query(
          'prescription_bills',
          columns: ['id'],
          where: 'prescription_id = ? AND is_deleted = 0',
          whereArgs: [prescriptionId],
          limit: 1,
        );
      } else {
        final doctorId = data['doctor_id'];
        final rxNo = data['prescription_no']?.toString().trim() ?? '';
        if (doctorId != null && rxNo.isNotEmpty) {
          existing = await txn.query(
            'prescription_bills',
            columns: ['id'],
            where: 'doctor_id = ? AND prescription_no = ? AND is_deleted = 0',
            whereArgs: [doctorId, rxNo],
            limit: 1,
          );
        }
      }

      if (existing.isNotEmpty) {
        final id = existing.first['id'] as int;
        await txn.update(
          'prescription_bills',
          data,
          where: 'id = ?',
          whereArgs: [id],
        );
        return id;
      }

      return txn.insert('prescription_bills', data);
    });
  }

  Future<int> updatePrescriptionBill(
    int id,
    Map<String, dynamic> data,
  ) async {
    final db = await database;

    data['sync_status'] = 'pending';

    data['updated_at'] = DateTime.now().toIso8601String();

    return db.update(
      'prescription_bills',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getBillsByDoctor(
    int doctorId,
  ) async {
    final db = await database;

    return db.query(
      'prescription_bills',
      where: 'doctor_id = ? AND is_deleted = 0',
      whereArgs: [doctorId],
      orderBy: 'id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getBillsByPatient(
    int patientId,
  ) async {
    final db = await database;

    return db.query(
      'prescription_bills',
      where: 'patient_id = ? AND is_deleted = 0',
      whereArgs: [patientId],
      orderBy: 'id DESC',
    );
  }

  Future<Map<String, dynamic>?> getBillByPrescription(
    int prescriptionId,
  ) async {
    final db = await database;

    final result = await db.query(
      'prescription_bills',
      where: 'prescription_id = ? AND is_deleted = 0',
      whereArgs: [prescriptionId],
      limit: 1,
    );

    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getPendingBills() async {
    final db = await database;

    return db.query(
      'prescription_bills',
      where: 'sync_status = ? OR sync_status = ?',
      whereArgs: ['pending', 'failed'],
      orderBy: 'id ASC',
    );
  }

  Future<void> markBillSynced(
    int localId,
    int serverId,
    int serverVersion,
  ) async {
    final db = await database;

    await db.update(
      'prescription_bills',
      {
        'server_id': serverId,
        'server_version': serverVersion,
        'sync_status': 'synced',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> markBillSyncFailed(
    int localId,
  ) async {
    final db = await database;

    await db.update(
      'prescription_bills',
      {
        'sync_status': 'failed',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<Map<String, dynamic>?> getPatientByLocalId(int localId) async {
    final db = await database;
    final rows = await db.query(
      'patients',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [localId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getPrescriptionByLocalId(int localId) async {
    final db = await database;
    final rows = await db.query(
      'prescriptions',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [localId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertBillFromServer({
    required int doctorId,
    required Map<String, dynamic> bill,
  }) async {
    final db = await database;
    final serverId = bill['id'] as int;

    var existing = await db.query(
      'prescription_bills',
      where: 'doctor_id = ? AND server_id = ?',
      whereArgs: [doctorId, serverId],
      limit: 1,
    );

    if (bill['isDeleted'] == true) {
      if (existing.isNotEmpty) {
        await db.delete(
          'prescription_bills',
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }
      return;
    }

    int? localPatientId;
    final serverPatientId = bill['patientId'] as int?;
    if (serverPatientId != null) {
      final patient = await db.query(
        'patients',
        columns: ['id'],
        where: 'doctor_id = ? AND server_id = ? AND is_deleted = 0',
        whereArgs: [doctorId, serverPatientId],
        limit: 1,
      );
      if (patient.isNotEmpty) localPatientId = patient.first['id'] as int;
    }

    int? localPrescriptionId;
    final serverPrescriptionId = bill['prescriptionId'] as int?;
    if (serverPrescriptionId != null) {
      final prescription = await db.query(
        'prescriptions',
        columns: ['id'],
        where: 'doctor_id = ? AND server_id = ? AND is_deleted = 0',
        whereArgs: [doctorId, serverPrescriptionId],
        limit: 1,
      );
      if (prescription.isNotEmpty) {
        localPrescriptionId = prescription.first['id'] as int;
      }
    }

    if (existing.isEmpty && localPrescriptionId != null) {
      existing = await db.query(
        'prescription_bills',
        where: 'doctor_id = ? AND prescription_id = ?',
        whereArgs: [doctorId, localPrescriptionId],
        limit: 1,
      );
    }

    final data = <String, dynamic>{
      'server_id': serverId,
      'server_version': bill['version'] ?? 1,
      'doctor_id': doctorId,
      'patient_id': localPatientId,
      'prescription_id': localPrescriptionId,
      'prescription_no': bill['prescriptionNo']?.toString() ?? '',
      'consultation_fee': bill['consultationFee'] ?? 0,
      'medicine_charges': bill['medicineCharges'] ?? 0,
      'other_charges': bill['otherCharges'] ?? 0,
      'discount_amount': bill['discountAmount'] ?? 0,
      'total_amount': bill['totalAmount'] ?? 0,
      'paid_amount': bill['paidAmount'] ?? 0,
      'balance_amount': bill['balanceAmount'] ?? 0,
      'payment_method': bill['paymentMethod']?.toString() ?? '',
      'payment_status': bill['paymentStatus']?.toString() ?? '',
      'notes': bill['notes']?.toString() ?? '',
      'sync_status': 'synced',
      'is_deleted': 0,
      'created_at': bill['createdAt']?.toString(),
      'updated_at': bill['updatedAt']?.toString(),
    };

    if (existing.isEmpty) {
      await db.insert('prescription_bills', data);
    } else {
      await db.update(
        'prescription_bills',
        data,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
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
    int serverVersion = 1,
  }) async {
    final db = await database;

    final existing = await db.query(
      'patients',
      where: 'server_id = ? AND doctor_id = ?',
      whereArgs: [serverId, doctorId],
      limit: 1,
    );

    if (existing.isNotEmpty &&
        existing.first['sync_status']?.toString() == 'conflict') {
      await db.update(
        'patients',
        {
          'server_version': serverVersion,
          'conflict_server_json': jsonEncode({
            'id': serverId,
            'patientName': patientName,
            'patientAge': patientAge,
            'patientGender': patientGender,
            'phoneNumber': phoneNumber,
            'address': address,
            'notes': notes,
            'version': serverVersion,
            'updatedAt': updatedAt,
          }),
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return;
    }

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
      'server_version': serverVersion,
      'conflict_server_json': null,
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

  Future<void> bulkUpsertPatientsFromServer({
    required int doctorId,
    required List<dynamic> patients,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      for (final item in patients) {
        final p = Map<String, dynamic>.from(item as Map);

        final serverId = p['id'] as int;
        if (p['isDeleted'] == true) {
          await txn.delete(
            'patients',
            where: 'doctor_id = ? AND server_id = ?',
            whereArgs: [doctorId, serverId],
          );
          continue;
        }

        final phone = p['phoneNumber']?.toString() ?? '';

        final existing = await txn.query(
          'patients',
          where:
              '(server_id = ? AND doctor_id = ?) OR (phone_number = ? AND doctor_id = ?)',
          whereArgs: [serverId, doctorId, phone, doctorId],
          limit: 1,
        );

        if (existing.isNotEmpty &&
            existing.first['sync_status']?.toString() == 'conflict') {
          await txn.update(
            'patients',
            {
              'server_version': p['version'] ?? 1,
              'conflict_server_json': jsonEncode(p),
            },
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
          continue;
        }

        final data = {
          'server_id': serverId,
          'doctor_id': doctorId,
          'patient_name': (p['patientName'] ?? '').toString(),
          'patient_age': (p['patientAge'] ?? p['age'] ?? '').toString(),
          'patient_gender':
              (p['patientGender'] ?? p['gender'] ?? '').toString(),
          'phone_number': p['phoneNumber']?.toString(),
          'address': p['address']?.toString(),
          'notes': p['notes']?.toString(),
          'allergies': p['allergies']?.toString() ?? '',
          'chronic_diseases': p['chronicDiseases']?.toString() ?? '',
          'important_alerts': p['importantAlerts']?.toString() ?? '',
          if (p['queueStatus'] != null || p['queue_status'] != null)
            'queue_status': (p['queueStatus'] ?? p['queue_status']).toString(),
          if (p['queueNo'] != null || p['queue_no'] != null)
            'queue_no': int.tryParse(
              (p['queueNo'] ?? p['queue_no']).toString(),
            ),
          if (p['queueDate'] != null || p['queue_date'] != null)
            'queue_date': (p['queueDate'] ?? p['queue_date']).toString(),
          'sync_status': 'synced',
          'is_deleted': 0,
          'server_version': p['version'] ?? 1,
          'conflict_server_json': null,
          'updated_at':
              p['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
          'created_at':
              p['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
        };

        if (existing.isEmpty) {
          await txn.insert('patients', data);
        } else {
          await txn.update(
            'patients',
            data,
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
        }
      }
    });
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
    required int serverVersion,
    Map<String, dynamic>? serverPayload,
  }) async {
    final db = await database;

    final patient = await db.query(
      'patients',
      where: 'server_id = ? AND doctor_id = ?',
      whereArgs: [serverPatientId, doctorId],
      limit: 1,
    );

    int? localPatientId;

    if (patient.isNotEmpty) {
      localPatientId = patient.first['id'] as int;
    }

    final existing = await db.query(
      'prescriptions',
      where: 'server_id = ? AND doctor_id = ?',
      whereArgs: [serverId, doctorId],
      limit: 1,
    );

    if (existing.isNotEmpty &&
        existing.first['sync_status']?.toString() == 'conflict') {
      await db.update(
        'prescriptions',
        {
          'server_version': serverVersion,
          'conflict_server_json': jsonEncode(serverPayload ?? const {}),
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return;
    }

    final data = {
      'server_id': serverId,
      'doctor_id': doctorId,
      'patient_id': localPatientId ?? 0,
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
      'server_version': serverVersion,
      'conflict_server_json': null,
      'is_deleted': 0,
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

  Future<List<Map<String, dynamic>>> getTodayFollowUps({
    required int doctorId,
  }) async {
    final db = await database;

    final today = DateTime.now().toIso8601String().substring(0, 10);

    return await db.query(
      'prescriptions',
      where: 'doctor_id = ? AND follow_up_date LIKE ? AND follow_up_status = ?',
      whereArgs: [
        doctorId,
        '$today%',
        'pending',
      ],
      orderBy: 'follow_up_date ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getUpcomingFollowUps({
    required int doctorId,
  }) async {
    final db = await database;

    final today = DateTime.now().toIso8601String().substring(0, 10);

    return db.query(
      'prescriptions',
      where: 'doctor_id = ? AND follow_up_date > ? AND follow_up_status = ?',
      whereArgs: [
        doctorId,
        today,
        'pending',
      ],
      orderBy: 'follow_up_date ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getOverdueFollowUps({
    required int doctorId,
  }) async {
    final db = await database;

    final today = DateTime.now().toIso8601String().substring(0, 10);

    return db.query(
      'prescriptions',
      where: 'doctor_id = ? AND follow_up_date < ? AND follow_up_status = ?',
      whereArgs: [
        doctorId,
        today,
        'pending',
      ],
      orderBy: 'follow_up_date ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getCompletedFollowUps({
    required int doctorId,
  }) async {
    final db = await database;

    return db.query(
      'prescriptions',
      where: 'doctor_id = ? AND follow_up_status = ?',
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
        'follow_up_status': 'completed',
      },
      where: 'id = ?',
      whereArgs: [prescriptionId],
    );
  }

  Future<Map<String, dynamic>> getTodayIncomeSummaryByDoctor(
    int doctorId,
  ) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final result = await db.rawQuery(
      '''
    SELECT 
      COUNT(*) as bill_count,
      SUM(total_amount) as total_income,
      SUM(consultation_fee) as consultation_income,
      SUM(medicine_charges) as medicine_income,
      SUM(paid_amount) as paid_total,
      SUM(balance_amount) as balance_total
    FROM prescription_bills
    WHERE doctor_id = ?
      AND is_deleted = 0
      AND created_at LIKE ?
    ''',
      [doctorId, '$today%'],
    );

    return result.first;
  }

  Future<List<Map<String, dynamic>>> getTodayBillsByDoctor(
    int doctorId,
  ) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    return db.query(
      'prescription_bills',
      where: 'doctor_id = ? AND is_deleted = 0 AND created_at LIKE ?',
      whereArgs: [doctorId, '$today%'],
      orderBy: 'id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllBills() async {
    final db = await database;
    final doctorId = await DoctorSession.getActiveDoctorIdForData();
    if (doctorId == null) return [];

    return db.query(
      'prescription_bills',
      where: 'doctor_id = ? AND is_deleted = 0',
      whereArgs: [doctorId],
      orderBy: 'id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getTodayQueuePatients({
    String? status,
    int? limit,
    int offset = 0,
  }) async {
    final db = await database;
    final doctorId = await DoctorSession.getActiveDoctorIdForData();
    final today = DateTime.now().toIso8601String().split('T').first;

    if (doctorId == null) return [];

    if (status == null || status == 'waiting') {
      return db.query(
        'patients',
        where: 'doctor_id = ? AND date(queue_date) = date(?) AND '
            '(queue_status = ? OR queue_status = ?)',
        whereArgs: [doctorId, today, 'Waiting', 'Serving'],
        orderBy: 'queue_no ASC, id ASC',
        limit: limit,
        offset: limit == null ? null : offset,
      );
    }

    return db.query(
      'patients',
      where:
          'doctor_id = ? AND date(queue_date) = date(?) AND queue_status = ?',
      whereArgs: [doctorId, today, status],
      orderBy: 'queue_no ASC, id ASC',
      limit: limit,
      offset: limit == null ? null : offset,
    );
  }

  Future<List<Map<String, dynamic>>> getPreviousPendingQueuePatients({
    int? limit,
    int offset = 0,
  }) async {
    final db = await database;
    final doctorId = await DoctorSession.getActiveDoctorIdForData();
    final today = DateTime.now().toIso8601String().split('T').first;

    if (doctorId == null) return [];

    return db.query(
      'patients',
      where: 'doctor_id = ? AND date(queue_date) < date(?) AND '
          '(queue_status = ? OR queue_status = ?)',
      whereArgs: [doctorId, today, 'Waiting', 'Serving'],
      orderBy: 'queue_date ASC, queue_no ASC, id ASC',
      limit: limit,
      offset: limit == null ? null : offset,
    );
  }

  Future<void> cacheQueuePatientsFromServer({
    required int doctorId,
    required List<dynamic> patients,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      for (final item in patients) {
        final patient = Map<String, dynamic>.from(item as Map);
        final serverId = int.tryParse(patient['id']?.toString() ?? '');

        if (serverId == null) continue;

        final existing = await txn.query(
          'patients',
          where: 'server_id = ? AND doctor_id = ?',
          whereArgs: [serverId, doctorId],
          limit: 1,
        );

        final localSyncStatus = existing.isEmpty
            ? ''
            : existing.first['sync_status']?.toString() ?? '';

        if (existing.isNotEmpty && localSyncStatus == 'conflict') {
          await txn.update(
            'patients',
            {
              'server_version': patient['version'] ?? 1,
              'conflict_server_json': jsonEncode(patient),
            },
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
          continue;
        }

        if (existing.isNotEmpty && localSyncStatus == 'pending') {
          continue;
        }

        final isDeleted = patient['isDeleted'] == true ||
            patient['is_deleted'] == 1 ||
            patient['is_deleted'] == true;

        if (isDeleted) {
          if (existing.isNotEmpty) {
            await txn.delete(
              'patients',
              where: 'id = ?',
              whereArgs: [existing.first['id']],
            );
          }
          continue;
        }

        final data = <String, dynamic>{
          'server_id': serverId,
          'doctor_id': doctorId,
          'patient_name': (patient['patientName'] ?? '').toString(),
          'patient_age':
              (patient['patientAge'] ?? patient['age'] ?? '').toString(),
          'patient_gender':
              (patient['patientGender'] ?? patient['gender'] ?? '').toString(),
          'phone_number': patient['phoneNumber']?.toString(),
          'address': patient['address']?.toString(),
          'notes': patient['notes']?.toString(),
          'allergies': patient['allergies']?.toString() ?? '',
          'chronic_diseases': patient['chronicDiseases']?.toString() ?? '',
          'important_alerts': patient['importantAlerts']?.toString() ?? '',
          'queue_status':
              (patient['queueStatus'] ?? patient['queue_status'] ?? 'Waiting')
                  .toString(),
          'queue_no': int.tryParse(
            (patient['queueNo'] ?? patient['queue_no'] ?? serverId).toString(),
          ),
          'queue_date': (patient['queueDate'] ??
                  patient['queue_date'] ??
                  patient['createdAt'] ??
                  now)
              .toString(),
          'sync_status': 'synced',
          'is_deleted': 0,
          'server_version': patient['version'] ?? 1,
          'conflict_server_json': null,
          'updated_at': patient['updatedAt']?.toString() ?? now,
          'created_at': patient['createdAt']?.toString() ?? now,
        };

        if (existing.isEmpty) {
          await txn.insert('patients', data);
        } else {
          await txn.update(
            'patients',
            data,
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
        }
      }
    });
  }

  Future<void> moveQueuePatientToToday(int patientId) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().split('T').first;

    final result = await db.rawQuery(
      '''
    SELECT MAX(queue_no) AS max_no
    FROM patients
    WHERE date(queue_date) = date(?)
    ''',
      [today],
    );

    final nextQueueNo = ((result.first['max_no'] as num?)?.toInt() ?? 0) + 1;

    await db.update(
      'patients',
      {
        'queue_date': today,
        'queue_no': nextQueueNo,
        'queue_status': 'Waiting',
        'sync_status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [patientId],
    );
  }
}
//
