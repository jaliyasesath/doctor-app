import '../../../data/local/database_helper.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/data/api_auth_service.dart';
import '../../auth/data/credential_storage.dart';
import '../../auth/data/doctor_session.dart';
import '../../net_service/token_storage.dart';
import '../../patient/data/api_patient_service.dart';
import '../../prescription/data/api_prescription_service.dart';
import 'network_service.dart';
import '../../medicines/data/api_medicine_service.dart';
import '../../prescription/data/api_instruction_service.dart';
import '../../billing/data/api_bill_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sync_error_policy.dart';

class SyncResult {
  int doctorSuccess = 0;
  int doctorFailed = 0;
  int patientSuccess = 0;
  int patientFailed = 0;
  int patientConflicts = 0;
  int medicineSuccess = 0;
  int medicineFailed = 0;
  int prescriptionSuccess = 0;
  int prescriptionFailed = 0;
  int prescriptionConflicts = 0;
  int billSuccess = 0;
  int billFailed = 0;
  int pulledPatients = 0;
  int pulledPrescriptions = 0;
  int pulledMedicines = 0;
  int pulledBills = 0;

  String lastError = '';

  bool get hasFailures =>
      doctorFailed > 0 ||
      patientFailed > 0 ||
      patientConflicts > 0 ||
      medicineFailed > 0 ||
      prescriptionFailed > 0 ||
      prescriptionConflicts > 0 ||
      billFailed > 0;
}

class SyncService {
  static bool _syncInProgress = false;

  final ApiInstructionService _instructionApi = ApiInstructionService();
  final ApiMedicineService _medicineApi = ApiMedicineService();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final ApiAuthService _authApi = ApiAuthService();
  final ApiPatientService _patientApi = ApiPatientService();
  final ApiPrescriptionService _prescriptionApi = ApiPrescriptionService();
  final ApiBillService _billApi = ApiBillService();

  Future<bool> hasPendingLocalChanges() async {
    final pending = await Future.wait([
      _db.getPendingDoctors(),
      _db.getPendingPatients(),
      _db.getPendingMedicines(),
      _db.getPendingPrescriptions(),
      _db.getPendingCustomInstructions(),
      _db.getPendingBills(),
    ]);

    return pending.any((items) => items.isNotEmpty);
  }

  Future<void> resetSyncTimestamps() async {
    final prefs = await SharedPreferences.getInstance();
    final doctorId = await DoctorSession.getActiveDoctorIdForData();

    await prefs.remove('last_patients_sync_at');
    await prefs.remove('last_prescriptions_sync_at');
    await prefs.remove('last_medicines_sync_at');
    await prefs.remove('last_bills_sync_at');

    if (doctorId != null) {
      await prefs.remove('last_patients_sync_at_$doctorId');
      await prefs.remove('last_prescriptions_sync_at_$doctorId');
      await prefs.remove('last_medicines_sync_at_$doctorId');
      await prefs.remove('last_bills_sync_at_$doctorId');
    }
  }

  Future<SyncResult> syncAll() async {
    if (_syncInProgress) {
      final result = SyncResult();
      result.lastError = 'Sync already in progress';
      return result;
    }

    _syncInProgress = true;

    try {
      return await _performSync();
    } finally {
      _syncInProgress = false;
    }
  }

  Future<SyncResult> _performSync() async {
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

    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      result.lastError = 'Online session not found. Please login again.';
      return result;
    }

    await syncPatients(result);
    await syncMedicines(result);
    await syncCustomInstructions();
    await syncPrescriptions(result);
    await syncBills(result);

    await pullPatients(result);
    await pullPrescriptions(result);
    await pullMedicines(result);
    await pullBills(result);

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
      }
    }
  }

  Future<void> pullPatients(SyncResult result) async {
    final doctorId = await DoctorSession.getActiveDoctorIdForData();

    if (doctorId == null) {
      result.lastError = 'Doctor session not found';
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final syncKey = 'last_patients_sync_at_$doctorId';
      final lastSyncAt = _withSyncOverlap(prefs.getString(syncKey));

      int page = 1;
      const pageSize = 500;

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

        if (patients.length < pageSize) {
          break;
        }

        page++;

        await Future.delayed(
          const Duration(milliseconds: 1),
        );
      }

      await prefs.setString(
        syncKey,
        syncStartedAt,
      );
    } catch (e) {
      result.lastError = SyncErrorPolicy.message('Pull patients', e);
    }
  }

  Future<void> pullPrescriptions(SyncResult result) async {
    final doctorId = await DoctorSession.getActiveDoctorIdForData();

    if (doctorId == null) {
      result.lastError = 'Doctor session not found';
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final syncKey = 'last_prescriptions_sync_at_$doctorId';
      final lastSyncAt = _withSyncOverlap(prefs.getString(syncKey));

      int page = 1;
      const pageSize = 500;

      final syncStartedAt = DateTime.now().toUtc().toIso8601String();

      while (true) {
        final prescriptions = await _prescriptionApi.getPrescriptions(
          page: page,
          pageSize: pageSize,
          updatedAfter: lastSyncAt,
        );

        if (prescriptions.isEmpty) {
          break;
        }

        for (final rx in prescriptions) {
          final serverId = rx['id'] as int;
          if (rx['isDeleted'] == true) {
            await _db.markPrescriptionDeletedFromServer(
              doctorId: doctorId,
              serverId: serverId,
            );
            result.pulledPrescriptions++;
            continue;
          }

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
            serverId: serverId,
            serverPatientId: rx['patientId'] as int,
            serverVersion: (rx['version'] as num?)?.toInt() ?? 1,
            serverPayload: rx,
            patientName: (rx['patientName'] ?? '').toString(),
            patientAge: (rx['patientAge'] ?? '').toString(),
            patientGender: (rx['patientGender'] ?? '').toString(),
            prescriptionNo: (rx['prescriptionNo'] ?? '').toString(),
            prescriptionDate: (rx['prescriptionDate'] ?? '').toString(),
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

        if (prescriptions.length < pageSize) {
          break;
        }

        page++;
      }

      await prefs.setString(
        syncKey,
        syncStartedAt,
      );
    } catch (e) {
      result.lastError = SyncErrorPolicy.message('Pull prescriptions', e);
    }
  }

  Future<void> pullMedicines(SyncResult result) async {
    final doctorId = await DoctorSession.getActiveDoctorIdForData();

    if (doctorId == null) {
      result.lastError = 'Doctor session not found';
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final syncKey = 'last_medicines_sync_at_$doctorId';
    final lastSyncAt = _withSyncOverlap(prefs.getString(syncKey));
    final syncStartedAt = DateTime.now().toUtc().toIso8601String();

    try {
      int page = 1;
      const pageSize = 100;

      while (true) {
        final medicines = lastSyncAt == null
            ? await _medicineApi.getMedicines(
                page: page,
                pageSize: pageSize,
              )
            : await _medicineApi.getMedicineChanges(
                updatedAfter: lastSyncAt,
                page: page,
                pageSize: pageSize,
              );

        if (medicines.isEmpty) break;

        for (final item in medicines) {
          final map = Map<String, dynamic>.from(item as Map);
          final serverId = int.tryParse(map['id']?.toString() ?? '');

          if (serverId == null) continue;

          if (map['isDeleted'] == true) {
            await _db.markMedicineDeletedFromServer(
              doctorId: doctorId,
              serverId: serverId,
              updatedAt: map['updatedAt']?.toString(),
            );
            result.pulledMedicines++;
            continue;
          }

          await _db.upsertMedicineFromServer(
            doctorId: doctorId,
            serverId: serverId,
            medicineName: (map['medicineName'] ?? '').toString(),
            genericName: map['genericName']?.toString(),
            brandName: map['brandName']?.toString(),
            drugGroup: map['drugGroup']?.toString(),
            doseForm: map['medicineType']?.toString(),
            strength: map['defaultDosage']?.toString(),
            customMedicineName: map['customMedicineName']?.toString(),
            customGenericName: map['customGenericName']?.toString(),
            customBrandName: map['customBrandName']?.toString(),
            customDrugGroup: map['customDrugGroup']?.toString(),
            customMedicineType: map['customMedicineType']?.toString(),
            customDosage: map['customDosage']?.toString(),
            customFrequency: map['customFrequency']?.toString(),
            customDuration: map['customDuration']?.toString(),
            customInstructions: map['customInstructions']?.toString(),
            sellingPrice: double.tryParse(
                  map['sellingPrice']?.toString() ?? '0',
                ) ??
                0,
            costPrice: double.tryParse(
                  map['costPrice']?.toString() ?? '0',
                ) ??
                0,
            isFavorite: map['isFavorite'] == true ? 1 : 0,
            createdAt: map['createdAt']?.toString(),
            updatedAt: map['updatedAt']?.toString(),
          );

          result.pulledMedicines++;
        }

        if (medicines.length < pageSize) break;
        page++;
      }

      // Advance only after every page and local write succeeds.
      await prefs.setString(
        syncKey,
        syncStartedAt,
      );
    } catch (e) {
      // Keep old timestamp so the next auto-sync retries all failed changes.
      result.medicineFailed++;
      result.lastError = SyncErrorPolicy.message('Pull medicines', e);
    }
  }

  String? _withSyncOverlap(String? value) {
    if (value == null || value.isEmpty) return null;

    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;

    return parsed
        .subtract(const Duration(minutes: 2))
        .toUtc()
        .toIso8601String();
  }

  Future<void> syncDoctors(SyncResult result) async {
    final pendingDoctors = await _db.getPendingDoctors();

    for (final doctor in pendingDoctors) {
      final localId = doctor['id'] as int;
      final email = doctor['email']?.toString() ?? '';
      final password = await CredentialStorage.getPassword(email) ??
          doctor['password']?.toString() ??
          '';

      if (password.isEmpty) {
        await _db.markDoctorSyncFailed(localId);
        result.doctorFailed++;
        result.lastError = 'Doctor sync requires the user to log in again.';
        continue;
      }

      try {
        // Doctor registration now requires live identity verification,
        // including the SLMC/NIC front and back images and explicit consent.
        // Therefore an old offline doctor record must never be registered
        // automatically in the background. If the account already exists and
        // is approved, login can safely reconnect the legacy local record.
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

        await _db.markDoctorSyncFailed(localId);
        result.doctorFailed++;
        result.lastError =
            'Doctor registration requires online identity verification. '
            'Open the registration screen and upload both ID images.';
      } catch (e) {
        await _db.markDoctorSyncFailed(localId);
        result.doctorFailed++;
        result.lastError = SyncErrorPolicy.message('Doctor sync', e);
      }
    }
  }

  Future<void> syncPatients(SyncResult result) async {
    final pendingPatients = await _db.getPendingPatients();

    for (final patient in pendingPatients) {
      final localId = patient['id'] as int;

      try {
        final isDeleted = (patient['is_deleted'] ?? 0) == 1;
        final serverId = patient['server_id'] as int?;
        final expectedVersion =
            (patient['server_version'] as num?)?.toInt() ?? 0;
        if (isDeleted) {
          if (serverId != null && serverId > 0) {
            await _patientApi.deletePatient(serverId, expectedVersion);
          }
          await _db.removeSyncedPatientTombstone(localId);
          result.patientSuccess++;
          continue;
        }

        final apiResult = await _patientApi.upsertPatient(
          serverId: serverId,
          name: patient['patient_name']?.toString() ?? '',
          age: patient['patient_age']?.toString() ?? '',
          gender: patient['patient_gender']?.toString() ?? '',
          phone: patient['phone_number']?.toString() ?? '',
          address: patient['address']?.toString() ?? '',
          notes: patient['notes']?.toString() ?? '',
          allergies: patient['allergies']?.toString() ?? '',
          chronicDiseases: patient['chronic_diseases']?.toString() ?? '',
          importantAlerts: patient['important_alerts']?.toString() ?? '',
          expectedVersion: serverId == null ? null : expectedVersion,
        );

        if (apiResult['success'] == true && apiResult['serverId'] != null) {
          await _db.markPatientSynced(
            localId,
            apiResult['serverId'] as int,
            (apiResult['version'] as num?)?.toInt() ?? 1,
          );
          result.patientSuccess++;
        } else {
          await _db.markPatientSyncFailed(localId);
          result.patientFailed++;
          result.lastError = 'Patient API invalid response: $apiResult';
        }
      } on AppException catch (e) {
        if (e.isConflict && e.code == 'PATIENT_VERSION_CONFLICT') {
          await _db.markPatientSyncConflict(localId, e.userMessage);
          result.patientConflicts++;
          result.lastError = e.userMessage;
          continue;
        }
        await _db.markPatientSyncFailed(localId);
        result.patientFailed++;
        result.lastError = SyncErrorPolicy.message('Patient sync', e);
      } catch (e) {
        await _db.markPatientSyncFailed(localId);
        result.patientFailed++;
        result.lastError = SyncErrorPolicy.message('Patient sync', e);
      }
    }
  }

  Future<void> syncPrescriptions(SyncResult result) async {
    final pendingPrescriptions = await _db.getPendingPrescriptions();

    for (final rx in pendingPrescriptions) {
      final localRxId = rx['id'] as int;

      try {
        final isDeleted = (rx['is_deleted'] ?? 0) == 1;
        final serverId = rx['server_id'] as int?;
        final expectedVersion = (rx['server_version'] as num?)?.toInt() ?? 0;
        if (isDeleted) {
          if (serverId != null && serverId > 0) {
            await _prescriptionApi.deletePrescription(
              serverId,
              expectedVersion,
            );
          }
          await _db.removeSyncedPrescriptionTombstone(localRxId);
          result.prescriptionSuccess++;
          continue;
        }

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

        final localItems = await _db.getPrescriptionItems(localRxId);
        final items = localItems.isNotEmpty
            ? localItems.map((item) => {
                  'medicineId': item['medicine_id'],
                  'medicineName': item['medicine_name']?.toString() ?? '',
                  'dosage': item['dosage']?.toString() ?? '',
                  'frequency': item['frequency']?.toString() ?? '',
                  'duration': item['duration']?.toString() ?? '',
                  'instructions': item['instructions']?.toString() ?? '',
                  'quantity': _asDouble(item['quantity']),
                  'prescriptionOnly':
                      (item['prescription_only'] as num?)?.toInt() == 1,
                }).toList()
            : _parseItemsText(rx['items_text']?.toString() ?? '');

        final apiResult = await _prescriptionApi.upsertPrescription(
          serverId: serverId,
          serverPatientId: serverPatientId,
          prescriptionNo: rx['prescription_no']?.toString() ?? '',
          prescriptionDate: rx['prescription_date']?.toString() ??
              DateTime.now().toIso8601String(),
          complaint: rx['complaint']?.toString() ?? '',
          diagnosis: rx['diagnosis']?.toString() ?? '',
          visitNotes: rx['visit_notes']?.toString() ?? '',
          qrValue: rx['prescription_no']?.toString() ?? '',
          items: items,
          expectedVersion: serverId == null ? null : expectedVersion,
        );

        if (apiResult['success'] == true && apiResult['serverId'] != null) {
          await _db.markPrescriptionSynced(
            localRxId,
            apiResult['serverId'] as int,
            serverPatientId,
            (apiResult['version'] as num?)?.toInt() ?? 1,
          );
          result.prescriptionSuccess++;
        } else {
          await _db.markPrescriptionSyncFailed(localRxId);
          result.prescriptionFailed++;
          result.lastError = 'Prescription API invalid response: $apiResult';
        }
      } on AppException catch (e) {
        if (e.isConflict && e.code == 'PRESCRIPTION_VERSION_CONFLICT') {
          await _db.markPrescriptionSyncConflict(
            localRxId,
            e.userMessage,
          );
          result.prescriptionConflicts++;
          result.lastError = e.userMessage;
          continue;
        }
        await _db.markPrescriptionSyncFailed(localRxId);
        result.prescriptionFailed++;
        result.lastError = SyncErrorPolicy.message('Prescription sync', e);
      } catch (e) {
        await _db.markPrescriptionSyncFailed(localRxId);
        result.prescriptionFailed++;
        result.lastError = SyncErrorPolicy.message('Prescription sync', e);
      }
    }
  }

  Future<void> syncBills(SyncResult result) async {
    final pendingBills = await _db.getPendingBills();

    for (final bill in pendingBills) {
      final localId = bill['id'] as int;
      try {
        int? serverPatientId;
        final localPatientId = bill['patient_id'] as int?;
        if (localPatientId != null && localPatientId > 0) {
          final patient = await _db.getPatientByLocalId(localPatientId);
          serverPatientId = patient?['server_id'] as int?;
          if (serverPatientId == null || serverPatientId <= 0) {
            await _db.markBillSyncFailed(localId);
            result.billFailed++;
            result.lastError = 'Bill sync error: patient is not synced.';
            continue;
          }
        }

        int? serverPrescriptionId;
        final localPrescriptionId = bill['prescription_id'] as int?;
        if (localPrescriptionId != null && localPrescriptionId > 0) {
          final prescription =
              await _db.getPrescriptionByLocalId(localPrescriptionId);
          serverPrescriptionId = prescription?['server_id'] as int?;
          if (serverPrescriptionId == null || serverPrescriptionId <= 0) {
            await _db.markBillSyncFailed(localId);
            result.billFailed++;
            result.lastError = 'Bill sync error: prescription is not synced.';
            continue;
          }
        }

        final serverId = bill['server_id'] as int?;
        final version = (bill['server_version'] as int?) ?? 0;
        final apiResult = await _billApi.upsertBill(
          serverId: serverId,
          serverPatientId: serverPatientId,
          serverPrescriptionId: serverPrescriptionId,
          prescriptionNo: bill['prescription_no']?.toString() ?? '',
          consultationFee: _asDouble(bill['consultation_fee']),
          medicineCharges: _asDouble(bill['medicine_charges']),
          otherCharges: _asDouble(bill['other_charges']),
          discountAmount: _asDouble(bill['discount_amount']),
          totalAmount: _asDouble(bill['total_amount']),
          paidAmount: _asDouble(bill['paid_amount']),
          balanceAmount: _asDouble(bill['balance_amount']),
          paymentMethod: bill['payment_method']?.toString() ?? '',
          paymentStatus: bill['payment_status']?.toString() ?? '',
          notes: bill['notes']?.toString() ?? '',
          expectedVersion: serverId == null ? null : version,
        );

        final newServerId = apiResult['serverId'] as int?;
        final newVersion = apiResult['version'] as int?;
        if (apiResult['success'] == true &&
            newServerId != null &&
            newVersion != null) {
          await _db.markBillSynced(localId, newServerId, newVersion);
          result.billSuccess++;
        } else {
          await _db.markBillSyncFailed(localId);
          result.billFailed++;
          result.lastError = 'Bill API invalid response: $apiResult';
        }
      } catch (error) {
        await _db.markBillSyncFailed(localId);
        result.billFailed++;
        result.lastError = SyncErrorPolicy.message('Bill sync', error);
      }
    }
  }

  Future<void> pullBills(SyncResult result) async {
    final doctorId = await DoctorSession.getActiveDoctorIdForData();
    if (doctorId == null) {
      result.lastError = 'Doctor session not found';
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final syncKey = 'last_bills_sync_at_$doctorId';
    final lastSyncAt = _withSyncOverlap(prefs.getString(syncKey));
    final syncStartedAt = DateTime.now().toUtc().toIso8601String();

    try {
      var page = 1;
      const pageSize = 500;
      while (true) {
        final bills = await _billApi.getBills(
          page: page,
          pageSize: pageSize,
          updatedAfter: lastSyncAt,
        );
        if (bills.isEmpty) break;

        for (final bill in bills) {
          await _db.upsertBillFromServer(
            doctorId: doctorId,
            bill: bill,
          );
          result.pulledBills++;
        }

        if (bills.length < pageSize) break;
        page++;
      }

      await prefs.setString(syncKey, syncStartedAt);
    } catch (error) {
      result.billFailed++;
      result.lastError = SyncErrorPolicy.message('Pull bills', error);
    }
  }

  double _asDouble(Object? value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0;

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
            customMedicineName: med['custom_medicine_name']?.toString(),
            customGenericName: med['custom_generic_name']?.toString(),
            customBrandName: med['custom_brand_name']?.toString(),
            customDrugGroup: med['custom_drug_group']?.toString(),
            customMedicineType: med['custom_medicine_type']?.toString(),
            customDosage: med['custom_dosage']?.toString(),
            customFrequency: med['custom_frequency']?.toString(),
            customDuration: med['custom_duration']?.toString(),
            customInstructions: med['custom_instructions']?.toString(),
            sellingPrice: double.tryParse(
                  med['selling_price']?.toString() ?? '0',
                ) ??
                0,
            costPrice: double.tryParse(
                  med['cost_price']?.toString() ?? '0',
                ) ??
                0,
            isFavorite: med['is_favorite'] == 1,
          );
        } else {
          final activeDoctorId = await DoctorSession.getActiveDoctorIdForData();

          apiResult = await _medicineApi.createMedicine(
            doctorId: activeDoctorId ?? (med['doctor_id'] as int),
            name: med['medicine_name']?.toString() ?? '',
            generic: med['generic_name']?.toString(),
            brand: med['brand_name']?.toString(),
            group: med['drug_group']?.toString(),
            doseForm: med['dose_form']?.toString(),
            strength: med['strength']?.toString(),
            customMedicineName: med['custom_medicine_name']?.toString(),
            customGenericName: med['custom_generic_name']?.toString(),
            customBrandName: med['custom_brand_name']?.toString(),
            customDrugGroup: med['custom_drug_group']?.toString(),
            customMedicineType: med['custom_medicine_type']?.toString(),
            customDosage: med['custom_dosage']?.toString(),
            customFrequency: med['custom_frequency']?.toString(),
            customDuration: med['custom_duration']?.toString(),
            customInstructions: med['custom_instructions']?.toString(),
            sellingPrice: double.tryParse(
                  med['selling_price']?.toString() ?? '0',
                ) ??
                0,
            costPrice: double.tryParse(
                  med['cost_price']?.toString() ?? '0',
                ) ??
                0,
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
        result.lastError = SyncErrorPolicy.message('Medicine sync', e);
      }
    }
  }
}
