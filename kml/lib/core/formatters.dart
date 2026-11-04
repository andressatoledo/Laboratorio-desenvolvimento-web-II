import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatação de valores para exibição (sempre em pt_BR).
class Fmt {
  static final _money =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2);
  static final _plain = NumberFormat('#,##0.00', 'pt_BR');
  static final _qty = NumberFormat('#,##0.###', 'pt_BR');
  static final _input = NumberFormat('0.###########', 'pt_BR');

  /// Dinheiro guardado em centavos (inteiro) -> "R$ 1.234,56".
  static String money(int cents) => _money.format(cents / 100);

  /// Igual a [money], sem o símbolo (usado dentro dos campos de texto).
  static String moneyPlain(int cents) => _plain.format(cents / 100);

  /// Quantidade sem zeros desnecessários: 12,5 / 3 / 0,125.
  static String qty(double v) => _qty.format(v);

  /// Número com casas fixas (ex.: consumo 11,42).
  static String fixed(double v, int decimals) =>
      NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: decimals)
          .format(v);

  /// Valor decimal para preencher um campo de edição (sem separador de milhar).
  static String input(double v) => _input.format(v);

  /// Hoje às 00:00 (só a data). Use no lugar de DateTime.now() para datas.
  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static String date(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
  static String dateShort(DateTime d) => DateFormat('dd/MM').format(d);

  /// Formato de armazenamento no banco (ordenável como texto).
  static String iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  static DateTime parseIso(String s) => DateTime.parse(s);
}

/// Conversão segura do que o usuário digitou.
class Parse {
  /// "1.234,56" -> 123456 centavos. Vazio vira 0.
  static int cents(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? 0 : int.parse(digits);
  }

  /// "12,5" ou "12.5" -> 12.5. Retorna null se inválido.
  static double? decimal(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));
}

/// Campo de dinheiro estilo "caixa registradora": os dígitos entram pela
/// direita (digitou 1 2 3 -> 1,23). Evita erros de vírgula e de formato.
class CurrencyInputFormatter extends TextInputFormatter {
  static const _maxDigits = 11; // até R$ 999.999.999,99
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > _maxDigits) digits = digits.substring(0, _maxDigits);
    if (digits.isEmpty) return const TextEditingValue();
    final text = Fmt.moneyPlain(int.parse(digits));
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Campo decimal que só aceita número válido, com no máximo [maxDecimals]
/// casas e [maxIntDigits] dígitos inteiros. Troca "." por ",".
class DecimalInputFormatter extends TextInputFormatter {
  DecimalInputFormatter({this.maxDecimals = 2, this.maxIntDigits = 7})
      : _re = RegExp('^\\d{0,$maxIntDigits}([,.]\\d{0,$maxDecimals})?\$');

  final int maxDecimals;
  final int maxIntDigits;
  final RegExp _re;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (!_re.hasMatch(newValue.text)) return oldValue;
    return newValue.copyWith(text: newValue.text.replaceAll('.', ','));
  }
}
