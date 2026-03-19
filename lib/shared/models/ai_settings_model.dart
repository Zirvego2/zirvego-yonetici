/// Firestore `ai_settings` koleksiyonundaki belgeye karşılık gelen model.
/// Belge ID = bayId (int → String).
class AiSettingsModel {
  // ── AI Otomatik Atama ─────────────────────────────────────────────────────
  final bool aiEnabled;            // AI ataması aktif mi
  final int  aiMaxPackages;        // Kuryeye max atanabilecek paket sayısı
  final int  aiWaitTime;           // Atama öncesi bekleme süresi (dk)

  // ── Kurye Onayı ───────────────────────────────────────────────────────────
  final bool courierApprovalEnabled; // Kurye onayı zorunlu mu
  final int  approvalTimeout;        // Kurye onay zaman aşımı (sn)

  // ── Otomatik Hazır ────────────────────────────────────────────────────────
  final bool autoReadyEnabled; // Teslimat sonrası kurye otomatik hazır durumuna geçsin

  // ── Grup Atama ────────────────────────────────────────────────────────────
  final bool groupAssignmentEnabled;  // Grup atama aktif mi
  final int  groupDirectionThreshold; // Kuryenin yön eşiği (derece)

  // ── Sipariş Önceliği ─────────────────────────────────────────────────────
  final int latestOrderPriorityMinutes; // Son X dakika içindeki siparişler öncelikli

  // ── Mesafe Ayarları ───────────────────────────────────────────────────────
  final int businessToPackageDistance; // İşletme-paket arasındaki max mesafe (m)

  // ── Meta ──────────────────────────────────────────────────────────────────
  final int bayId;

  const AiSettingsModel({
    required this.aiEnabled,
    required this.aiMaxPackages,
    required this.aiWaitTime,
    required this.courierApprovalEnabled,
    required this.approvalTimeout,
    required this.autoReadyEnabled,
    required this.groupAssignmentEnabled,
    required this.groupDirectionThreshold,
    required this.latestOrderPriorityMinutes,
    required this.businessToPackageDistance,
    required this.bayId,
  });

  // ── Varsayılan değerler ──────────────────────────────────────────────────
  factory AiSettingsModel.defaults(int bayId) => AiSettingsModel(
        aiEnabled:                   false,
        aiMaxPackages:               3,
        aiWaitTime:                  1,
        courierApprovalEnabled:      false,
        approvalTimeout:             120,
        autoReadyEnabled:            true,
        groupAssignmentEnabled:      false,
        groupDirectionThreshold:     30,
        latestOrderPriorityMinutes:  15,
        businessToPackageDistance:   3000,
        bayId:                       bayId,
      );

  // ── Firestore → Model ────────────────────────────────────────────────────
  factory AiSettingsModel.fromMap(Map<String, dynamic> m) => AiSettingsModel(
        aiEnabled:                   m['aiEnabled']                   as bool? ?? false,
        aiMaxPackages:               (m['aiMaxPackages']               as num?)?.toInt() ?? 3,
        aiWaitTime:                  (m['aiWaitTime']                  as num?)?.toInt() ?? 1,
        courierApprovalEnabled:      m['courierApprovalEnabled']       as bool? ?? false,
        approvalTimeout:             (m['approvalTimeout']             as num?)?.toInt() ?? 120,
        autoReadyEnabled:            m['autoReadyEnabled']             as bool? ?? true,
        groupAssignmentEnabled:      m['groupAssignmentEnabled']       as bool? ?? false,
        groupDirectionThreshold:     (m['groupDirectionThreshold']     as num?)?.toInt() ?? 30,
        latestOrderPriorityMinutes:  (m['latestOrderPriorityMinutes']  as num?)?.toInt() ?? 15,
        businessToPackageDistance:   (m['businessToPackageDistance']   as num?)?.toInt() ?? 3000,
        bayId:                       (m['bayId']                       as num?)?.toInt() ?? 0,
      );

  // ── Model → Firestore ────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
        'aiEnabled':                  aiEnabled,
        'aiMaxPackages':              aiMaxPackages,
        'aiWaitTime':                 aiWaitTime,
        'courierApprovalEnabled':     courierApprovalEnabled,
        'approvalTimeout':            approvalTimeout,
        'autoReadyEnabled':           autoReadyEnabled,
        'groupAssignmentEnabled':     groupAssignmentEnabled,
        'groupDirectionThreshold':    groupDirectionThreshold,
        'latestOrderPriorityMinutes': latestOrderPriorityMinutes,
        'businessToPackageDistance':  businessToPackageDistance,
        'bayId':                      bayId,
      };

  // ── Kopyala ve değiştir ──────────────────────────────────────────────────
  AiSettingsModel copyWith({
    bool? aiEnabled,
    int?  aiMaxPackages,
    int?  aiWaitTime,
    bool? courierApprovalEnabled,
    int?  approvalTimeout,
    bool? autoReadyEnabled,
    bool? groupAssignmentEnabled,
    int?  groupDirectionThreshold,
    int?  latestOrderPriorityMinutes,
    int?  businessToPackageDistance,
  }) =>
      AiSettingsModel(
        aiEnabled:                  aiEnabled                  ?? this.aiEnabled,
        aiMaxPackages:              aiMaxPackages              ?? this.aiMaxPackages,
        aiWaitTime:                 aiWaitTime                 ?? this.aiWaitTime,
        courierApprovalEnabled:     courierApprovalEnabled     ?? this.courierApprovalEnabled,
        approvalTimeout:            approvalTimeout            ?? this.approvalTimeout,
        autoReadyEnabled:           autoReadyEnabled           ?? this.autoReadyEnabled,
        groupAssignmentEnabled:     groupAssignmentEnabled     ?? this.groupAssignmentEnabled,
        groupDirectionThreshold:    groupDirectionThreshold    ?? this.groupDirectionThreshold,
        latestOrderPriorityMinutes: latestOrderPriorityMinutes ?? this.latestOrderPriorityMinutes,
        businessToPackageDistance:  businessToPackageDistance  ?? this.businessToPackageDistance,
        bayId:                      bayId,
      );
}
