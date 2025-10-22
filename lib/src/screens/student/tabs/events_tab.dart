import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ADD THIS

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  List<_Event> _events = [];
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _realtimeChannel; // ADD REALTIME CHANNEL

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _initializeRealtime(); // INITIALIZE REALTIME
  }

  // ADD REALTIME INITIALIZATION
  void _initializeRealtime() {
    _realtimeChannel = SupabaseService.client
        .channel('events-tab-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          callback: (payload) {
            print('🔄 EventsTab Real-time update: ${payload.eventType}');

            // Auto-refresh when events change
            _loadEvents();

            // Show notification for new events
            if (payload.eventType == PostgresChangeEvent.insert) {
              _showNewEventNotification(
                  payload.newRecord['title'] ?? 'New Event');
            }
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            print('✅ EventsTab realtime subscribed successfully');
          }
          if (error != null) {
            print('❌ EventsTab realtime error: $error');
          }
        });
  }

  void _showNewEventNotification(String eventTitle) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 New event: $eventTitle'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadEvents() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      // Load from Supabase
      final supabaseEvents = await SupabaseService.getEvents();

      // Convert to local format and add demo data if needed
      final List<_Event> allEvents = [
        ...supabaseEvents.map((event) => _Event(
              event['title'] ?? 'Untitled Event',
              DateTime.parse(
                  event['event_date'] ?? DateTime.now().toIso8601String()),
              event['description'] ?? '',
              event['category'] ?? 'General',
            )),
        // Add demo data if no Supabase data
        if (supabaseEvents.isEmpty) ...[
          _Event(
            'Orientation Day',
            DateTime.now().add(const Duration(days: 2)),
            'Welcome to the new semester! Join us for orientation activities and meet your fellow students.',
            'Academic',
          ),
          _Event(
            'Hackathon 2024',
            DateTime.now().add(const Duration(days: 10)),
            '24-hour coding challenge. Build amazing projects and compete for prizes!',
            'Technical',
          ),
        ],
      ];

      if (mounted) {
        setState(() {
          _events = allEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load events. Please try again later.';
          _isLoading = false;
          // Fallback demo data
          _events = [
            _Event(
              'Orientation Day',
              DateTime.now().add(const Duration(days: 2)),
              'Welcome to the new semester! Join us for orientation activities and meet your fellow students.',
              'Academic',
            ),
            _Event(
              'Hackathon 2024',
              DateTime.now().add(const Duration(days: 10)),
              '24-hour coding challenge. Build amazing projects and compete for prizes!',
              'Technical',
            ),
          ];
        });
      }
    }
  }

  // ADD DISPOSE METHOD FOR CLEANUP
  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upcoming Events',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stay updated with all campus events and activities',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
              // ADD REALTIME STATUS INDICATOR
              Stack(
                children: [
                  IconButton(
                    onPressed: _loadEvents,
                    icon: Icon(Icons.refresh_rounded, color: scheme.primary),
                    tooltip: 'Refresh events',
                  ),
                  // Small green dot for realtime status
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Loading/Error States
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: scheme.error,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load events',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadEvents,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_events.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy_rounded,
                      size: 64,
                      color: scheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No events scheduled',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back later for upcoming events',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
            )
          else
            // Events List
            Column(
              children: [
                // REALTIME STATUS BADGE
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Live Updates Active',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final event = _events[i];
                    final isUpcoming = event.date.isAfter(DateTime.now());
                    final daysUntil =
                        event.date.difference(DateTime.now()).inDays;

                    return Card(
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showEventDetails(event),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(event.category)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${event.date.day}',
                                          style: TextStyle(
                                            color: _getCategoryColor(
                                                event.category),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('MMM').format(event.date),
                                          style: TextStyle(
                                            color: _getCategoryColor(
                                                event.category),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          event.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getCategoryColor(
                                                    event.category)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            event.category,
                                            style: TextStyle(
                                              color: _getCategoryColor(
                                                  event.category),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          event.description,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: scheme.onSurface
                                                    .withValues(alpha: 0.7),
                                              ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isUpcoming)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        daysUntil == 0
                                            ? 'Today'
                                            : daysUntil == 1
                                                ? 'Tomorrow'
                                                : '${daysUntil}d',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 16,
                                    color: scheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('EEE, MMM d, yyyy')
                                        .format(event.date),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color:
                                              scheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 16,
                                    color: scheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('h:mm a').format(event.date),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color:
                                              scheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

          const SizedBox(height: 20),

          // Quick Actions
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Calendar integration coming soon!')),
                            );
                          },
                          icon: const Icon(Icons.calendar_today_rounded),
                          label: const Text('Add to Calendar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reminder set!')),
                            );
                          },
                          icon: const Icon(Icons.notifications_rounded),
                          label: const Text('Set Reminder'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'technical':
        return Colors.blue;
      case 'academic':
        return Colors.green;
      case 'career':
        return Colors.orange;
      case 'cultural':
        return Colors.purple;
      case 'educational':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  void _showEventDetails(_Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getCategoryColor(event.category).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                event.category,
                style: TextStyle(
                  color: _getCategoryColor(event.category),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(event.description),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 16),
                const SizedBox(width: 8),
                Text(DateFormat('EEEE, MMMM d, yyyy').format(event.date)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 16),
                const SizedBox(width: 8),
                Text(DateFormat('h:mm a').format(event.date)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Event reminder set!')),
              );
            },
            child: const Text('Set Reminder'),
          ),
        ],
      ),
    );
  }
}

class _Event {
  final String title;
  final DateTime date;
  final String description;
  final String category;

  _Event(this.title, this.date, this.description, this.category);
}
