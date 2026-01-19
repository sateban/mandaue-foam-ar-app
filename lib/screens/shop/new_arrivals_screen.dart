import 'package:flutter/material.dart';
import '../../data/dummy_data.dart';

class NewArrivalsScreen extends StatefulWidget {
  const NewArrivalsScreen({super.key});

  @override
  State<NewArrivalsScreen> createState() => _NewArrivalsScreenState();
}

class _NewArrivalsScreenState extends State<NewArrivalsScreen> {
  late List<Map<String, dynamic>> _products;
  int _itemsToShow = 4;
  final int _itemsPerLoad = 4;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _products = List.from(dummyProducts);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (_itemsToShow < _products.length) {
        _loadMoreItems();
      }
    }
  }

  void _loadMoreItems() {
    setState(() {
      _itemsToShow = (_itemsToShow + _itemsPerLoad).clamp(0, _products.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'New Arrivals',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A8A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        itemCount: _itemsToShow + (_itemsToShow < _products.length ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _itemsToShow) {
            // Loading indicator
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: _itemsToShow < _products.length
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFFFDB022)),
                      )
                    : const Text(
                        'No more items',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
              ),
            );
          }
          return _buildNewArrivalItem(_products[index]);
        },
      ),
    );
  }

  Widget _buildNewArrivalItem(Map<String, dynamic> product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                product['imageUrl'] ?? '',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: Colors.grey,
                      size: 40,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'],
                  style: const TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${product['price'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            color: Color(0xFFFDB022), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${product['rating']}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Icon(
              product['isFavorite'] ? Icons.favorite : Icons.favorite_border,
              color: product['isFavorite'] ? Colors.red : Colors.grey,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
