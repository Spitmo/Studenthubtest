import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final List<_Event> _events = [
    _Event('Orientation Day', DateTime.now().add(const Duration(days: 2)), 'Welcome to the new semester! Join us for orientation activities and meet your fellow students.', 'Main Auditorium', '09:00 AM'),
    _Event('Hackathon 2024', DateTime.now().add(const Duration(days: 10)), '24-hour coding challenge. Build amazing projects and compete for prizes!', 'Computer Lab', '10:00 AM'),
    _Event('Guest Lecture', DateTime.now().add(const Duration(days: 20)), 'AI in Education by Dr. Smith. Learn about the future of technology in learning.', 'Lecture Hall 1', '02:00 PM'),
    _Event('Career Fair', DateTime.now().add(const Duration(days: 30)), 'Meet with top companies and explore career opportunities.', 'Exhibition Hall', '09:00 AM'),
    _Event('Cultural Festival', DateTime.now().add(const Duration(days: 45)), 'Celebrate diversity with performances, food, and cultural displays.', 'Open Ground', '06:00 PM'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final df = DateFormat('EEE, d MMM');
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
              color: scheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          
          // Events List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
        itemCount: _events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, i) {
              final event = _events[i];
              final isUpcoming = event.date.isAfter(DateTime.now());
              final daysUntil = event.date.difference(DateTime.now()).inDays;
              
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
                                color: scheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${event.date.day}',
                                    style: TextStyle(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM').format(event.date),
                                    style: TextStyle(
                                      color: scheme.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    event.description,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurface.withOpacity(0.7),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isUpcoming)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  daysUntil == 0 ? 'Today' : daysUntil == 1 ? 'Tomorrow' : '${daysUntil}d',
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
                              Icons.location_on_rounded,
                              size: 16,
                              color: scheme.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              event.location,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: scheme.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              event.time,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurface.withOpacity(0.6),
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
                              const SnackBar(content: Text('Calendar integration coming soon!')),
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

  void _showEventDetails(_Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                Text(event.time),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 16),
                const SizedBox(width: 8),
                Text(event.location),
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
  final String location;
  final String time;
  _Event(this.title, this.date, this.description, this.location, this.time);
}


