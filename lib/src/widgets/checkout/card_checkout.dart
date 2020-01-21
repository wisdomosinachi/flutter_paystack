import 'package:flutter/material.dart';
import 'package:flutter_paystack/src/common/exceptions.dart';
import 'package:flutter_paystack/src/common/my_strings.dart';
import 'package:flutter_paystack/src/common/paystack.dart';
import 'package:flutter_paystack/src/common/utils.dart';
import 'package:flutter_paystack/src/models/card.dart';
import 'package:flutter_paystack/src/models/charge.dart';
import 'package:flutter_paystack/src/models/checkout_response.dart';
import 'package:flutter_paystack/src/models/transaction.dart';
import 'package:flutter_paystack/src/transaction/card_transaction_manager.dart';
import 'package:flutter_paystack/src/widgets/checkout/base_checkout.dart';
import 'package:flutter_paystack/src/widgets/checkout/checkout_widget.dart';
import 'package:flutter_paystack/src/widgets/input/card_input.dart';

class CardCheckout extends StatefulWidget {
  final Charge charge;
  final OnResponse<CheckoutResponse> onResponse;
  final ValueChanged<bool> onProcessingChange;
  final ValueChanged<PaymentCard> onCardChange;

  CardCheckout({
    @required this.charge,
    @required this.onResponse,
    @required this.onProcessingChange,
    @required this.onCardChange,
  });

  @override
  _CardCheckoutState createState() => _CardCheckoutState(charge, onResponse);
}

class _CardCheckoutState extends BaseCheckoutMethodState<CardCheckout> {
  final Charge _charge;

  _CardCheckoutState(this._charge, OnResponse<CheckoutResponse> onResponse)
      : super(onResponse, CheckoutMethod.card);

  @override
  Widget buildAnimatedChild() {
    var amountText = _charge.amount == null || _charge.amount.isNegative
        ? ''
        : Utils.formatAmount(_charge.amount);

    return new Container(
      alignment: Alignment.center,
      child: new Column(
        children: <Widget>[
          new Text(
            'Enter your card details to pay',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          new SizedBox(
            height: 20.0,
          ),
          new CardInput(
            buttonText: 'Pay $amountText',
            card: _charge.card,
            onValidated: _onCardValidated,
          ),
        ],
      ),
    );
  }

  void _onCardValidated(PaymentCard card) {
    _charge.card = card;
    widget.onCardChange(_charge.card);
    widget.onProcessingChange(true);

    if ((_charge.accessCode != null && _charge.accessCode.isNotEmpty) ||
        _charge.reference != null && _charge.reference.isNotEmpty) {
      _chargeCard(_charge);
    } else {
      // This should never happen. Validation has already been done in [PaystackPlugin .checkout]
      throw new ChargeException(Strings.noAccessCodeReference);
    }
  }

  void _chargeCard(Charge charge) {
    handleBeforeValidate(Transaction transaction) {
      // Do nothing
    }

    handleOnError(Object e, Transaction transaction) {
      if (!mounted) {
        return;
      }
      if (e is ExpiredAccessCodeException) {
        _chargeCard(charge);
        return;
      }

      String message = e.toString();
      if (transaction.reference != null && !(e is PaystackException)) {
        handleError(message, transaction.reference, true);
      } else {
        handleError(message, transaction.reference, false);
      }
    }

    handleOnSuccess(Transaction transaction) {
      if (!mounted) {
        return;
      }
      onResponse(new CheckoutResponse(
        message: transaction.message,
        reference: transaction.reference,
        status: true,
        method: method,
        card: _charge.card,
        verify: true,
      ));
    }

    new CardTransactionManager(
            charge: charge,
            context: context,
            beforeValidate: (transaction) => handleBeforeValidate(transaction),
            onSuccess: (transaction) => handleOnSuccess(transaction),
            onError: (error, transaction) => handleOnError(error, transaction))
        .chargeCard();
  }

  void handleError(String message, String reference, bool verify) {
    handleAllError(message, reference, verify, card: _charge.card);
  }
}
