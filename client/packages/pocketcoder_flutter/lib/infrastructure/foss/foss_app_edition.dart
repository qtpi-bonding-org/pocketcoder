import 'package:pocketcoder_flutter/domain/edition/i_app_edition.dart';

class FossAppEdition implements IAppEdition {
  const FossAppEdition();

  @override
  bool get isPro => false;
}
