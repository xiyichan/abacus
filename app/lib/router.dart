import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'features/events/event_stock_page.dart';
import 'features/events/events_page.dart';
import 'features/orders/order_detail_page.dart';
import 'features/orders/orders_page.dart';
import 'features/pos/pos_page.dart';
import 'features/products/categories_page.dart';
import 'features/products/product_editor_page.dart';
import 'features/products/products_page.dart';
import 'features/settings/payment_methods_page.dart';
import 'features/settings/support_page.dart';
import 'features/stats/stats_page.dart';
import 'features/settings/settings_page.dart';
import 'features/team/cloud_login_page.dart';
import 'features/team/join_team_page.dart';
import 'features/team/team_page.dart';
import 'ui/app_shell.dart';

/// [locked] 为 true（收银锁）时只能停在收银台首页，其他页面一律跳回去。
GoRouter createRouter({ValueListenable<bool>? locked}) => GoRouter(
  initialLocation: '/pos',
  refreshListenable: locked,
  redirect: (_, state) =>
      (locked?.value ?? false) && state.uri.path != '/pos' ? '/pos' : null,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/pos',
              builder: (_, _) => const PosPage(),
              routes: [
                GoRoute(
                  path: 'events',
                  builder: (_, _) => const EventsPage(),
                  routes: [
                    GoRoute(
                      path: ':eventId/stock',
                      builder: (_, state) => EventStockPage(
                        eventId: state.pathParameters['eventId']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/orders',
              builder: (_, _) => const OrdersPage(),
              routes: [
                GoRoute(
                  path: ':orderId',
                  builder: (_, state) => OrderDetailPage(
                    orderId: state.pathParameters['orderId']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/products',
              builder: (_, _) => const ProductsPage(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, _) => const ProductEditorPage(),
                ),
                GoRoute(
                  path: 'categories',
                  builder: (_, _) => const CategoriesPage(),
                ),
                GoRoute(
                  path: ':productId',
                  builder: (_, state) => ProductEditorPage(
                    productId: state.pathParameters['productId'],
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/stats', builder: (_, _) => const StatsPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsPage(),
              routes: [
                GoRoute(
                  path: 'payments',
                  builder: (_, _) => const PaymentMethodsPage(),
                ),
                GoRoute(
                  path: 'support',
                  builder: (_, _) => const SupportPage(),
                ),
                GoRoute(
                  path: 'team',
                  builder: (_, _) => const TeamPage(),
                  routes: [
                    GoRoute(
                      path: 'join',
                      builder: (_, _) => const JoinTeamPage(),
                    ),
                    GoRoute(
                      path: 'cloud',
                      builder: (_, state) => CloudLoginPage(
                        restore: state.uri.queryParameters['restore'] == '1',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
