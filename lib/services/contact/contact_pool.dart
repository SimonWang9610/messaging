import '../base/base_pool.dart';
import 'contact_service.dart';
import 'contact_cache.dart';

class ContactPool extends BasePool<ContactCache, ContactService> {
  static final _instance = ContactPool._();
  static ContactService getService() => _instance.service;

  ContactPool._();

  factory ContactPool() => _instance;

  @override
  void createCacheAndService() {
    cache = ContactCache();
    service = ContactService(cache);
  }
}
