import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/services/mock_store.dart';
import '../../home/presentation/home_providers.dart';

class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key});

  @override
  ConsumerState<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  int _step = 0;

  ListingType _type = ListingType.rent;
  Category? _category;
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _deposit = TextEditingController(text: '0');
  PriceUnit _unit = PriceUnit.day;
  final _city = TextEditingController(text: 'New York');
  int _quantity = 1;
  final _images = <String>[];
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _deposit.dispose();
    _city.dispose();
    super.dispose();
  }

  void _next() => setState(() => _step = (_step + 1).clamp(0, 4));
  void _prev() => setState(() => _step = (_step - 1).clamp(0, 4));

  bool get _canContinue {
    switch (_step) {
      case 0:
        return true;
      case 1:
        return _category != null;
      case 2:
        return _title.text.trim().length >= 3 && _desc.text.trim().length >= 10;
      case 3:
        return double.tryParse(_price.text) != null;
      default:
        return true;
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final store = ref.read(mockStoreProvider);
    final draft = Listing(
      id: 'temp',
      ownerId: store.currentUser.id,
      ownerName: store.currentUser.fullName,
      title: _title.text.trim(),
      description: _desc.text.trim(),
      categoryId: _category!.id,
      listingType: _type,
      price: double.parse(_price.text),
      priceUnit: _unit,
      securityDeposit: double.tryParse(_deposit.text) ?? 0,
      currency: 'USD',
      quantity: _quantity,
      images: List.of(_images),
      location: ListingLocation(city: _city.text.trim(), country: 'USA'),
    );
    await store.createListing(draft);
    if (!mounted) return;
    setState(() => _submitting = false);
    ref.invalidate(featuredListingsProvider);
    ref.invalidate(nearbyListingsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Listing submitted for review 🎉')),
    );
    context.go(AppRoutes.sellerDashboard);
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider).asData?.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create listing'),
        leading: _step == 0
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => context.go(AppRoutes.home))
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: _prev),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_step + 1) / 5, minHeight: 3),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildStep(cats),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _submitting
                    ? null
                    : (_canContinue
                        ? (_step == 4 ? _submit : _next)
                        : null),
                child: _submitting
                    ? const SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_step == 4 ? 'Publish' : 'Continue'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(List<Category> cats) {
    switch (_step) {
      case 0:
        return _stepWrap(
          'What are you offering?',
          'Choose how buyers will engage with your listing.',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ListingType.values
                .map((t) => ChoiceChip(
                      label: Text(_typeLabel(t)),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    ))
                .toList(),
          ),
        );
      case 1:
        return _stepWrap(
          'Category',
          'Pick the category that best fits.',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cats
                .map((c) => ChoiceChip(
                      label: Text(c.name),
                      selected: _category?.id == c.id,
                      onSelected: (_) => setState(() => _category = c),
                    ))
                .toList(),
          ),
        );
      case 2:
        return _stepWrap(
          'Describe your listing',
          'A clear title and description helps buyers decide faster.',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 4, maxLines: 8,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              const Text('Photos', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  ..._images.map((url) => ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.network(url,
                            width: 80, height: 80, fit: BoxFit.cover),
                      )),
                  InkWell(
                    onTap: () => setState(() {
                      _images.add(
                        'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400&sig=${_images.length}',
                      );
                    }),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      case 3:
        return _stepWrap(
          'Pricing',
          'Set your price and deposit. You can change these later.',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price', prefixText: '\$ '),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              if (_type != ListingType.sale)
                DropdownButtonFormField<PriceUnit>(
                  value: _unit,
                  decoration: const InputDecoration(labelText: 'Per'),
                  items: PriceUnit.values
                      .map((u) => DropdownMenuItem(value: u, child: Text(u.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _unit = v ?? _unit),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _deposit,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Security deposit', prefixText: '\$ '),
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Quantity available'),
                const Spacer(),
                IconButton.outlined(
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 12),
                Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                IconButton.outlined(
                  onPressed: () => setState(() => _quantity++),
                  icon: const Icon(Icons.add),
                ),
              ]),
            ],
          ),
        );
      case 4:
        return _stepWrap(
          'Location & preview',
          'Where is the item located?',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'City', prefixIcon: Icon(Icons.place_outlined)),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Preview', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(_title.text.trim().isEmpty ? '(No title)' : _title.text,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      '${_typeLabel(_type)} · ${_category?.name ?? '—'} · $_quantity available',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text('\$${_price.text.isEmpty ? '0' : _price.text}${_type == ListingType.sale ? '' : ' / ${_unit.name}'}',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'By publishing, you agree to Rent95\'s policies. Your listing will be reviewed within 24 hours.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _stepWrap(String title, String subtitle, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        child,
      ],
    );
  }

  String _typeLabel(ListingType t) => switch (t) {
        ListingType.rent => 'Rent',
        ListingType.sale => 'Sell',
        ListingType.service => 'Service',
        ListingType.hybrid => 'Rent or sell',
      };
}
