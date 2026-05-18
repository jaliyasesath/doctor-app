import '../../../data/local/database_helper.dart';
import '../../auth/data/api_auth_service.dart';
import '../../auth/data/doctor_session.dart';
import '../../patient/data/api_patient_service.dart';
import '../../prescription/data/api_prescription_service.dart';
import 'network_service.dart';
import '../../medicines/data/api_medicine_service.dart';
import '../../prescription/data/api_instruction_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncResult {
  int doctorSuccess = 0;
  int doctorFailed = 0;
  int patientSuccess = 0;
  int patientFailed = 0;
  int medicineSuccess = 0;
  int medicineFailed = 0;
  int prescriptionSuccess = 0;
  int prescriptionFailed = 0;
  int pulledPatients = 0;
  int pulledPrescriptions = 0;
  int pulledMedicines = 0;

  String lastError = '';

  bool get hasFailures =>
      doctorFailed > 0 ||
      patientFailed > 0 ||
      medicineFailed > 0 ||
      prescriptionFailed > 0;
}

class SyncService {
  final ApiInstructionService _instructionApi = ApiInstructionService();
  final ApiMedicineService _medicineApi = ApiMedicineService();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final ApiAuthService _authApi = ApiAuthService();
  final ApiPatientService _patientApi = ApiPatientService();
  final ApiPrescriptionService _prescriptionApi = ApiPrescriptionService();

  Future<SyncResult> syncAll() async {
    final result = SyncResult();

    final online = await NetworkService.isOnline();
    if (!online) {
      result.lastError = 'No internet';
      return result;
    }

    final doctor = await DoctorSession.getDoctor();
    if (doctor == null) {
      result.lastError = 'Doctor session not found. Please login again.';
      return result;
    }

    await syncDoctors(result);

    final email = doctor['email']?.toString() ?? '';
    final password = doctor['password']?.toString() ?? '';

    final loginResult = await _authApi.login(
      email: email,
      password: password,
    );

    if (loginResult['success'] != true) {
      result.lastError = 'Online login failed before sync';
      return result;
    }

    await syncPatients(result);
    await syncMedicines(result);
    await syncCustomInstructions();
    await syncPrescriptions(result);

    await pullPatients(result);
    await pullPrescriptions(result);
    await pullMedicines(result);

    return result;
  }

  Future<void> syncCustomInstructions() async {
    final pending = await _db.getPendingCustomInstructions();

    for (final item in pending) {
      try {
        final result = await _instructionApi.createInstruction(
          doctorId: item['doctor_id'] as int,
          instructionText: item['instruction_text']?.toString() ?? '',
        );

        if (result['success'] == true && result['serverId'] != null) {
          await _db.markCustomInstructionSynced(
            item['id'] as int,
            result['serverId'] as int,
          );
        } else {
          await _db.markCustomInstructionSyncFailed(item['id'] as int);
        }
      } catch (e) {
        await _db.markCustomInstructionSyncFailed(item['id'] as int);
        print('Custom instruction sync error: $e');
      }
    }
  }

  Future<void> pullPatients(SyncResult result) async {
  final doctorId = await DoctorSession.getDoctorId();

  if (doctorId == null) {
    result.lastError = 'Doctor session not found';
    return;
  }

  try {
    final prefs = await SharedPreferences.getInstance();

    final lastSyncAt = prefs.getString('last_patients_sync_at');

    int page = 1;
    const pageSize = 100;

    final syncStartedAt = DateTime.now().toUtc().toIso8601String();

    while (true) {
      final patients = await _patientApi.getPatients(
        page: page,
        pageSize: pageSize,
        updatedAfter: lastSyncAt,
      );

      if (patients.isEmpty) {
        break;
      }

      await _db.bulkUpsertPatientsFromServer(
        doctorId: doctorId,
        patients: patients,
      );

      result.pulledPatients += patients.length;

      page++;

      await Future.delayed(
        const Duration(milliseconds: 1),
      );
    }

    await prefs.setString(
      'last_patients_sync_at',
      syncStartedAt,
    );
  } catch (e) {
    result.lastError = 'Pull patients error: $e';
  }
}

  

  Future<void> pullPrescriptions(SyncResult result) async {
  final doctorId = await DoctorSession.getDoctorId();

  if (doctorId == null) {
    result.lastError = 'Doctor session not found';
    return;
  }

  try {
    final prefs = await SharedPreferences.getInstance();

    final lastSyncAt =
        prefs.getString('last_prescriptions_sync_at');

    int page = 1;
    const pageSize = 100;

    final syncStartedAt =
        DateTime.now().toUtc().toIso8601String();

    while (true) {
      final prescriptions =
          await _prescriptionApi.getPrescriptions(
        page: page,
        pageSize: pageSize,
        updatedAfter: lastSyncAt,
      );

      if (prescriptions.isEmpty) {
        break;
      }

      for (final rx in prescriptions) {
        final items = rx['items'] as List<dynamic>? ?? [];

        final itemsText = items.map((item) {
          final m = Map<String, dynamic>.from(item);

          return '${m['medicineName'] ?? ''} | '
              '${m['dosage'] ?? ''} | '
              '${m['frequency'] ?? ''} | '
              '${m['duration'] ?? ''} | '
              '${m['instructions'] ?? ''}';
        }).join('\n');

        await _db.upsertPrescriptionFromServer(
          doctorId: doctorId,
          serverId: rx['id'] as int,
          serverPatientId: rx['patientId'] as int,
          patientName: (rx['patientName'] ?? '').toString(),
          patientAge: (rx['patientAge'] ?? '').toString(),
          patientGender: (rx['patientGender'] ?? '').toString(),
          prescriptionNo: (rx['prescriptionNo'] ?? '').toString(),
          prescriptionDate:
              (rx['prescriptionDate'] ?? '').toString(),
          itemsText: itemsText,
          complaint: rx['complaint']?.toString(),
          diagnosis: rx['diagnosis']?.toString(),
          visitNotes: rx['visitNotes']?.toString(),
          updatedAt: rx['updatedAt']?.toString(),
        );

        result.pulledPrescriptions++;

        if (result.pulledPrescriptions % 100 == 0) {
          await Future.delayed(
            const Duration(milliseconds: 1),
          );
        }
      }

      page++;
    }

    await prefs.setString(
      'last_prescriptions_sync_at',
      syncStartedAt,
    );
  } catch (e) {
    result.lastError = 'Pull prescriptions error: $e';
  }
}

  Future<void> pullMedicines(SyncResult result) async {
  final doctorId = await DoctorSession.getDoctorId();

  if (doctorId == null) {
    result.lastError = 'Doctor session not found';
    return;
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncAt = prefs.getString('last_medicines_sync_at');

    int page = 1;
    const pageSize = 100;

    final syncStartedAt = DateTime.now().toUtc().toIso8601String();

    while (true) {
      final medicines = await _medicineApi.getMedicines(
        page: page,
        pageSize: pageSize,
        updatedAfter: lastSyncAt,
      );

      if (medicines.isEmpty) {
        break;
      }

      for (final m in medicines) {
        final map = Map<String, dynamic>.from(m as Map);

        await _db.upsertMedicineFromServer(
          doctorId: doctorId,
          serverId: map['id'] as int,
          medicineName: (map['medicineName'] ?? '').toString(),
          genericName: map['genericName']?.toString(),
          brandName: map['brandName']?.toString(),
          drugGroup: map['drugGroup']?.toString(),
          doseForm: map['medicineType']?.toString(),
          strength: map['defaultDosage']?.toString(),
          isFavorite: map['isFavorite'] == true ? 1 : 0,
          createdAt: map['createdAt']?.toString(),
          updatedAt: map['updatedAt']?.toString(),
        );

        result.pulledMedicines++;

        if (result.pulledMedicines % 100 == 0) {
          await Future.delayed(
            const Duration(milliseconds: 1),
          );
        }
      }

      page++;
    }

    await prefs.setString(
      'last_medicines_sync_at',
      syncStartedAt,
    );
  } catch (e) {
    result.lastError = 'Pull medicines error: $e';
    print('Pull medicines error: $e');
  }
}

  Future<void> syncDoctors(SyncResult result) async {
    final pendingDoctors = await _db.getPendingDoctors();

    for (final doctor in pendingDoctors) {
      final localId = doctor['id'] as int;
      final email = doctor['email']?.toString() ?? '';
      final password = doctor['password']?.toString() ?? '';

      try {
        final apiResult = await _authApi.register(
          doctorName: doctor['doctor_name']?.toString() ?? '',
          email: email,
          password: password,
          contactNumber: doctor['contact_number']?.toString() ?? '',
          specialization: doctor['specialization']?.toString() ?? '',
          role: doctor['role']?.toString() ?? 'Doctor',
          qualifications: doctor['qualifications']?.toString() ?? '',
          profession: doctor['profession']?.toString() ?? '',
          slmcRegNo: doctor['slmc_reg_no']?.toString() ?? '',
          affiliation: doctor['affiliation']?.toString() ?? '',
          medicalCenterName: doctor['medical_center_name']?.toString() ?? '',
          city: doctor['city']?.toString() ?? '',
          clinicAddress: doctor['clinic_address']?.toString() ?? '',
          biometricEnabled: doctor['biometric_enabled'] == 1 ? 1 : 0,
          saveLocal: false,
        );

        if (apiResult['success'] == true) {
          final serverId = apiResult['serverId'] ?? apiResult['doctorId'] ?? 0;
          await _db.markDoctorSynced(localId, serverId is int ? serverId : 0);
          result.doctorSuccess++;
          continue;
        }

        final message = apiResult['message']?.toString() ?? '';

        if (message.toLowerCase().contains('email already registered')) {
          final loginResult = await _authApi.login(
            email: email,
            password: password,
          );

          if (loginResult['success'] == true) {
            final doctorData = loginResult['doctor'] as Map<String, dynamic>;
            final serverId = doctorData['id'] ?? doctorData['serverId'] ?? 0;

            await _db.markDoctorSynced(
              localId,
              serverId is int ? serverId : 0,
            );

            result.doctorSuccess++;
            continue;
          }
        }

        await _db.markDoctorSyncFailed(localId);
        result.doctorFailed++;
        result.lastError = 'Doctor sync failed: $message';
      } catch (e) {
        await _db.markDoctorSyncFailed(localId);
        result.doctorFailed++;
        result.lastError = 'Doctor sync error: $e';
      }
    }
  }

  Future<void> syncPatients(SyncResult result) async {
    final pendingPatients = await _db.getPendingPatients();

    for (final patient in pendingPatients) {
      final localId = patient['id'] as int;

      try {
        final apiResult = await _patientApi.upsertPatient(
          serverId: patient['server_id'] as int?,
          name: patient['patient_name']?.toString() ?? '',
          age: patient['patient_age']?.toString() ?? '',
          gender: patient['patient_gender']?.toString() ?? '',
          phone: patient['phone_number']?.toString() ?? '',
          address: patient['address']?.toString() ?? '',
          notes: patient['notes']?.toString() ?? '',
        );

        if (apiResult['success'] == true && apiResult['serverId'] != null) {
          await _db.markPatientSynced(localId, apiResult['serverId'] as int);
          result.patientSuccess++;
        } else {
          await _db.markPatientSyncFailed(localId);
          result.patientFailed++;
          result.lastError = 'Patient API invalid response: $apiResult';
        }
      } catch (e) {
        await _db.markPatientSyncFailed(localId);
        result.patientFailed++;
        result.lastError = 'Patient sync error: $e';
      }
    }
  }

  Future<void> syncPrescriptions(SyncResult result) async {
    final pendingPrescriptions = await _db.getPendingPrescriptions();

    for (final rx in pendingPrescriptions) {
      final localRxId = rx['id'] as int;

      try {
        int? serverPatientId = rx['server_patient_id'] as int?;

        if (serverPatientId == null || serverPatientId == 0) {
          final localPatientId = rx['patient_id'] as int;
          final patient = await _db.getPatientById(localPatientId);

          if (patient == null || patient['server_id'] == null) {
            await _db.markPrescriptionSyncFailed(localRxId);
            result.prescriptionFailed++;
            result.lastError = 'Prescription sync error: patient not synced';
            continue;
          }

          serverPatientId = patient['server_id'] as int;
        }

        final items = _parseItemsText(rx['items_text']?.toString() ?? '');

        final apiResult = await _prescriptionApi.upsertPrescription(
          serverId: rx['server_id'] as int?,
          serverPatientId: serverPatientId,
          prescriptionNo: rx['prescription_no']?.toString() ?? '',
          prescriptionDate: rx['prescription_date']?.toString() ??
              DateTime.now().toIso8601String(),
          complaint: rx['complaint']?.toString() ?? '',
          diagnosis: rx['diagnosis']?.toString() ?? '',
          visitNotes: rx['visit_notes']?.toString() ?? '',
          qrValue: rx['prescription_no']?.toString() ?? '',
          items: items,
        );

        if (apiResult['success'] == true && apiResult['serverId'] != null) {
          await _db.markPrescriptionSynced(
            localRxId,
            apiResult['serverId'] as int,
            serverPatientId,
          );
          result.prescriptionSuccess++;
        } else {
          await _db.markPrescriptionSyncFailed(localRxId);
          result.prescriptionFailed++;
          result.lastError = 'Prescription API invalid response: $apiResult';
        }
      } catch (e) {
        await _db.markPrescriptionSyncFailed(localRxId);
        result.prescriptionFailed++;
        result.lastError = 'Prescription sync error: $e';
      }
    }
  }

  List<Map<String, dynamic>> _parseItemsText(String itemsText) {
    if (itemsText.trim().isEmpty) return [];

    return itemsText
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) {
      final parts = line.split('|').map((e) => e.trim()).toList();

      return {
        'medicineName': parts.isNotEmpty ? parts[0] : '',
        'dosage': parts.length > 1 ? parts[1] : '',
        'frequency': parts.length > 2 ? parts[2] : '',
        'duration': parts.length > 3 ? parts[3] : '',
        'instructions': parts.length > 4 ? parts[4] : '',
      };
    }).toList();
  }

  Future<void> syncMedicines(SyncResult result) async {
    final pending = await _db.getPendingMedicines();

    for (final med in pending) {
      try {
        final serverId = med['server_id'];
        final isDeleted = (med['is_deleted'] ?? 0) == 1;

if (isDeleted) {
  if (serverId != null && serverId != 0) {
    final deleteResult = await _medicineApi.deleteMedicine(
      serverId: serverId as int,
    );

    if (deleteResult['success'] == true) {
      await _db.permanentlyDeleteMedicine(med['id'] as int);
      result.medicineSuccess++;
    } else {
      await _db.markMedicineSyncFailed(med['id'] as int);
      result.medicineFailed++;
      result.lastError = 'Medicine delete failed: $deleteResult';
    }
  } else {
    await _db.permanentlyDeleteMedicine(med['id'] as int);
    result.medicineSuccess++;
  }

  continue;
}

        Map<String, dynamic> apiResult;

        if (serverId != null && serverId != 0) {
          apiResult = await _medicineApi.updateMedicine(
            serverId: serverId as int,
            name: med['medicine_name']?.toString() ?? '',
            generic: med['generic_name']?.toString(),
            brand: med['brand_name']?.toString(),
            group: med['drug_group']?.toString(),
            doseForm: med['dose_form']?.toString(),
            strength: med['strength']?.toString(),
            isFavorite: med['is_favorite'] == 1,
          );
        } else {
          apiResult = await _medicineApi.createMedicine(
            doctorId: med['doctor_id'] as int,
            name: med['medicine_name']?.toString() ?? '',
            generic: med['generic_name']?.toString(),
            brand: med['brand_name']?.toString(),
            group: med['drug_group']?.toString(),
            doseForm: med['dose_form']?.toString(),
            strength: med['strength']?.toString(),
            isFavorite: med['is_favorite'] == 1,
          );
        }

        if (apiResult['success'] == true && apiResult['serverId'] != null) {
          await _db.markMedicineSynced(
            med['id'] as int,
            apiResult['serverId'] as int,
          );
          result.medicineSuccess++;
        } else {
  final errorText = apiResult['error']?.toString().toLowerCase() ?? '';

  if (errorText.contains('already exists')) {
    await _db.markMedicineSynced(
      med['id'] as int,
      serverId is int ? serverId : 0,
    );

    result.medicineSuccess++;
  } else {
    await _db.markMedicineSyncFailed(med['id'] as int);
    result.medicineFailed++;
    result.lastError = 'Medicine API invalid response: $apiResult';
  }
}
      } catch (e) {
        await _db.markMedicineSyncFailed(med['id'] as int);
        result.medicineFailed++;
        result.lastError = 'Medicine sync error: $e';
        print('Medicine sync error: $e');
      }
    }
  }
}