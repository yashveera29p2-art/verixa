import 'package:firebase_auth/firebase_auth.dart';

/// Phone numbers of the Verixa team members who can approve recruiters and
/// hide reviews or job posts. Must match the list in firestore.rules.
const adminPhones = {'+919999999999'};

bool isAdmin(User? user) => adminPhones.contains(user?.phoneNumber);
