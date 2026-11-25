import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class AlarmeNotificacaoService {
  AlarmeNotificacaoService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _inicializado = false;

  /// Inicializa o fuso horário (Brasil/São Paulo) e o canal de som de alarme
  static Future<void> inicializar() async {
    if (_inicializado) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Solicita permissão de notificação e alarme exato no Android 13+
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    // Cria canal dedicado com som de ALARME e prioridade máxima para público 50+
    const canalAlarme = AndroidNotificationChannel(
      'cuidamed_alarmes_medicacao',
      'Alarmes de Medicação',
      description: 'Toques sonoros para lembrar o horário dos remédios',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    await androidPlugin?.createNotificationChannel(canalAlarme);
    _inicializado = true;
  }

  /// Agenda o pré-aviso (5 min antes) e o alarme principal (hora exata)
  static Future<void> agendarAlarmeRemedio({
    required String chaveUnica,
    required String nomeMedicamento,
    required String dosagem,
    required String horarioHhMm,
  }) async {
    await inicializar();

    final partes = horarioHhMm.split(':');
    if (partes.length < 2) return;

    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);
    if (hora == null || minuto == null) return;

    final agora = tz.TZDateTime.now(tz.local);
    var horarioExato = tz.TZDateTime(
      tz.local,
      agora.year,
      agora.month,
      agora.day,
      hora,
      minuto,
    );

    // Se o horário de hoje já passou, agenda para amanhã no mesmo horário
    if (horarioExato.isBefore(agora)) {
      horarioExato = horarioExato.add(const Duration(days: 1));
    }

    final horarioPreAviso = horarioExato.subtract(const Duration(minutes: 5));

    final int idPrincipal = chaveUnica.hashCode & 0x7FFFFFFF;
    final int idPreAviso = ('pre_$chaveUnica').hashCode & 0x7FFFFFFF;

    const detalhesAlarme = NotificationDetails(
      android: AndroidNotificationDetails(
        'cuidamed_alarmes_medicacao',
        'Alarmes de Medicação',
        channelDescription: 'Toques sonoros para lembrar o horário dos remédios',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true,
      ),
    );

    // 1. Agenda o pré-aviso de 5 minutos antes (se ainda não passou)
    if (horarioPreAviso.isAfter(agora)) {
      await _plugin.zonedSchedule(
        idPreAviso,
        'Em 5 minutos: $nomeMedicamento',
        'Prepare seu remédio ($dosagem) para às $horarioHhMm.',
        horarioPreAviso,
        detalhesAlarme,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    // 2. Agenda o alarme principal na hora exata
    await _plugin.zonedSchedule(
      idPrincipal,
      'Hora do remédio: $nomeMedicamento',
      'Tomar $dosagem agora ($horarioHhMm).',
      horarioExato,
      detalhesAlarme,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Cancela o alarme e o pré-aviso quando o paciente marca como TOMADO ou altera horário
  static Future<void> cancelarAlarmeRemedio(String chaveUnica) async {
    await inicializar();
    final int idPrincipal = chaveUnica.hashCode & 0x7FFFFFFF;
    final int idPreAviso = ('pre_$chaveUnica').hashCode & 0x7FFFFFFF;

    await _plugin.cancel(idPrincipal);
    await _plugin.cancel(idPreAviso);
  }

  /// Limpa todos os alarmes (útil ao sair da conta)
  static Future<void> cancelarTodos() async {
    await inicializar();
    await _plugin.cancelAll();
  }
}