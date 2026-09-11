import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Tim salona — horizontalna lista avatara sa imenom i ulogom (`docs/02 §3`).
///
/// Horizontalni scroll, a ne mreža: broj radnika ide od jednog do dvadeset, a mreža sa
/// jednim članom izgleda kao greška u rasporedu.
class TeamRow extends StatelessWidget {
  const TeamRow({required this.employees, super.key});

  final List<Employee> employees;

  static const double _visina = 132;
  static const double _promjer = 72;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: _visina,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: employees.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.lg),
        itemBuilder: (context, index) {
          final employee = employees[index];
          return SizedBox(
            width: 88,
            child: Column(
              children: [
                _Avatar(employee: employee, promjer: _promjer),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  employee.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
                if (employee.role.isNotEmpty)
                  Text(
                    employee.role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.employee, required this.promjer});

  final Employee employee;
  final double promjer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final inicijal = Center(
      child: Text(
        employee.name.trim().isEmpty
            ? '?'
            : employee.name.trim().characters.first.toUpperCase(),
        style: theme.textTheme.titleLarge?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
      ),
    );

    final url = employee.imageUrl;

    return Container(
      height: promjer,
      width: promjer,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? inicijal
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context, url) => const SizedBox.expand(),
              errorWidget: (context, url, error) => inicijal,
            ),
    );
  }
}
