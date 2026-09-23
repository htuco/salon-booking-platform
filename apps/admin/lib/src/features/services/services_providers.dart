import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../appointments/appointments_providers.dart';

/// Vrijednosti editora prije RPC poziva. Cijena ostaje decimalni tekst da put do
/// Postgres `numeric` kolone ne prolazi kroz binary floating point.
class ServiceInput {
  const ServiceInput({
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.durationMinutes,
    this.slotStepMinutes,
  });

  final String name;
  final String description;
  final String category;
  final String price;
  final int durationMinutes;

  /// `null` = salonski korak.
  final int? slotStepMinutes;
}

class ServiceActions {
  ServiceActions(this._ref);

  final Ref _ref;

  Future<Service> save(Service? existing, ServiceInput input) async {
    final salonId = _ref.read(adminSalonIdProvider);
    if (salonId == null) throw const ServerError('Salon nije učitan');

    final repository = _ref.read(serviceRepositoryProvider);
    final result = existing == null
        ? await repository.create(
            salonId: salonId,
            name: input.name,
            description: input.description,
            category: input.category,
            price: input.price,
            durationMinutes: input.durationMinutes,
            slotStepMinutes: input.slotStepMinutes,
          )
        : await repository.update(
            salonId: salonId,
            serviceId: existing.id,
            name: input.name,
            description: input.description,
            category: input.category,
            price: input.price,
            durationMinutes: input.durationMinutes,
            slotStepMinutes: input.slotStepMinutes,
            imageUrl: existing.imageUrl,
          );
    _ref.invalidate(adminServicesProvider);
    return result;
  }

  Future<void> setActive(Service service, bool isActive) async {
    final salonId = _ref.read(adminSalonIdProvider);
    if (salonId == null) throw const ServerError('Salon nije učitan');
    await _ref
        .read(serviceRepositoryProvider)
        .setActive(salonId: salonId, serviceId: service.id, isActive: isActive);
    _ref.invalidate(adminServicesProvider);
  }
}

final serviceActionsProvider = Provider<ServiceActions>(ServiceActions.new);

/// `12`, `12,5`, `12.50` -> decimalni tekst sa dvije decimale. Ne koristi `double`.
String? normalizeServicePrice(String raw) {
  final value = raw.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final decimals = parts.length == 1 ? '00' : parts[1].padRight(2, '0');
  return '${parts[0]}.$decimals';
}
