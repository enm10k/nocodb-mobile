import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/nocodb_sdk/models.dart' as model;
import 'package:nocodb/nocodb_sdk/symbols.dart';

const _emptyFormatters = <TextInputFormatter>[];
const _debounceDuration = Duration(milliseconds: 500);

String isnull(dynamic v) {
  if (v == null) {
    return '';
  }
  if (v is String && v != 'null') {
    return v;
  } else {
    return '';
  }
}

class TextEditor extends HookConsumerWidget {
  const TextEditor({
    super.key,
    required this.column,
    required this.onUpdate,
    this.initialValue = '',
    this.isNew = false,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.inputFormatters = _emptyFormatters,
  });
  final model.NcTableColumn column;
  final FnOnUpdate onUpdate;
  final dynamic initialValue;
  final bool isNew;
  final int? maxLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This flag is necessary to avoid unnecessary update.
    final changed = useState(false);

    final debounceTag = column.id.toString();

    final controller =
        useTextEditingController(text: isnull(initialValue.toString()));

    final focusNode = useFocusNode();
    useEffect(
      () {
        focusNode.addListener(() {
          if (!isNew && !focusNode.hasFocus && changed.value) {
            logger.info('lost focus');
            EasyDebounce.debounce(
              debounceTag,
              _debounceDuration,
              () {
                onUpdate({column.title: controller.value.text});
              },
            );
            EasyDebounce.fire(debounceTag);
            changed.value = false;
          }
        });
        return;
      },
      [focusNode],
    );

    return TextFormField(
      focusNode: focusNode,
      controller: controller,
      decoration: InputDecoration(
        border: InputBorder.none,
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.all(16),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      onEditingComplete: () {
        logger.info('onEditingComplete');
      },
      onFieldSubmitted: (value) {
        logger.info('onFieldSubmitted: $value');
        Navigator.pop(context);
      },
      onSaved: (value) {
        logger.info('onSaved: $value');
      },
      onChanged: (value) {
        logger.info('onChanged: $value');

        EasyDebounce.debounce(
          debounceTag,
          _debounceDuration,
          () {
            onUpdate({column.title: value});
          },
        );
        // }
        if (!changed.value) {
          changed.value = true;
        }
      },
    );
  }
}
