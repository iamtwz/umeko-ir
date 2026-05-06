import 'serial_adapter_factory_stub.dart'
    if (dart.library.io) 'serial_adapter_factory_io.dart'
    if (dart.library.js_interop) 'serial_adapter_factory_web.dart';

import 'serial_adapter.dart';

SerialAdapter createSerialAdapter() => createPlatformSerialAdapter();
