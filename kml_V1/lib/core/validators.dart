import 'formatters.dart';

/// Validações dos formulários. Cada função devolve a mensagem de erro
/// (ou null quando o valor é válido). As mesmas regras existem no banco
/// (CHECK constraints) como segunda barreira.
class V {
  /// Limite de valor monetário: R$ 9.999.999,99.
  static const maxCents = 999999999;

  static String? text(String? v,
      {required String label, int min = 1, int max = 80}) {
    final t = (v ?? '').trim();
    if (t.length < min) {
      return min <= 1
          ? 'Informe $label.'
          : '$label deve ter ao menos $min caracteres.';
    }
    if (t.length > max) return '$label deve ter no máximo $max caracteres.';
    return null;
  }

  static String? money(String? v, {required String label}) {
    final c = Parse.cents(v ?? '');
    if (c <= 0) return 'Informe $label maior que zero.';
    if (c > maxCents) return '$label máximo: R\$ 9.999.999,99.';
    return null;
  }

  static String? decimal(String? v,
      {required String label, required double min, required double max}) {
    final n = Parse.decimal(v ?? '');
    if (n == null) return 'Informe $label.';
    if (n < min || n > max) {
      return '$label deve ficar entre ${Fmt.qty(min)} e ${Fmt.qty(max)}.';
    }
    return null;
  }

  static String? integer(String? v,
      {required String label, required int min, required int max}) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return 'Informe $label.';
    if (n < min || n > max) {
      return '$label deve ficar entre ${Fmt.qty(min.toDouble())} e ${Fmt.qty(max.toDouble())}.';
    }
    return null;
  }

  static String? date(DateTime? d) {
    if (d == null) return 'Escolha a data.';
    final now = DateTime.now();
    if (d.isAfter(DateTime(now.year, now.month, now.day))) {
      return 'A data não pode estar no futuro.';
    }
    return null;
  }

  /// Placa opcional, antiga (ABC-1234) ou Mercosul (ABC1D23).
  static String? plate(String? v) {
    final p = normalizePlate(v);
    if (p == null) return null;
    return RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$').hasMatch(p)
        ? null
        : 'Placa inválida. Ex.: ABC1D23 ou ABC-1234.';
  }

  /// Maiúscula, sem hífen/espaços. Vazio vira null (placa é opcional).
  static String? normalizePlate(String? v) {
    final p = (v ?? '').toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    return p.isEmpty ? null : p;
  }
}
