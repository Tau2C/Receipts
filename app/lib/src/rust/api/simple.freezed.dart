// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'simple.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Store {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Store);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Store()';
}


}

/// @nodoc
class $StoreCopyWith<$Res>  {
$StoreCopyWith(Store _, $Res Function(Store) __);
}


/// Adds pattern-matching-related methods to [Store].
extension StorePatterns on Store {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( Store_Biedronka value)?  biedronka,TResult Function( Store_Lidl value)?  lidl,TResult Function( Store_Other value)?  other,required TResult orElse(),}){
final _that = this;
switch (_that) {
case Store_Biedronka() when biedronka != null:
return biedronka(_that);case Store_Lidl() when lidl != null:
return lidl(_that);case Store_Other() when other != null:
return other(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( Store_Biedronka value)  biedronka,required TResult Function( Store_Lidl value)  lidl,required TResult Function( Store_Other value)  other,}){
final _that = this;
switch (_that) {
case Store_Biedronka():
return biedronka(_that);case Store_Lidl():
return lidl(_that);case Store_Other():
return other(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( Store_Biedronka value)?  biedronka,TResult? Function( Store_Lidl value)?  lidl,TResult? Function( Store_Other value)?  other,}){
final _that = this;
switch (_that) {
case Store_Biedronka() when biedronka != null:
return biedronka(_that);case Store_Lidl() when lidl != null:
return lidl(_that);case Store_Other() when other != null:
return other(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  biedronka,TResult Function()?  lidl,TResult Function( String field0)?  other,required TResult orElse(),}) {final _that = this;
switch (_that) {
case Store_Biedronka() when biedronka != null:
return biedronka();case Store_Lidl() when lidl != null:
return lidl();case Store_Other() when other != null:
return other(_that.field0);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  biedronka,required TResult Function()  lidl,required TResult Function( String field0)  other,}) {final _that = this;
switch (_that) {
case Store_Biedronka():
return biedronka();case Store_Lidl():
return lidl();case Store_Other():
return other(_that.field0);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  biedronka,TResult? Function()?  lidl,TResult? Function( String field0)?  other,}) {final _that = this;
switch (_that) {
case Store_Biedronka() when biedronka != null:
return biedronka();case Store_Lidl() when lidl != null:
return lidl();case Store_Other() when other != null:
return other(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class Store_Biedronka extends Store {
  const Store_Biedronka(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Store_Biedronka);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Store.biedronka()';
}


}




/// @nodoc


class Store_Lidl extends Store {
  const Store_Lidl(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Store_Lidl);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Store.lidl()';
}


}




/// @nodoc


class Store_Other extends Store {
  const Store_Other(this.field0): super._();
  

 final  String field0;

/// Create a copy of Store
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Store_OtherCopyWith<Store_Other> get copyWith => _$Store_OtherCopyWithImpl<Store_Other>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Store_Other&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'Store.other(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $Store_OtherCopyWith<$Res> implements $StoreCopyWith<$Res> {
  factory $Store_OtherCopyWith(Store_Other value, $Res Function(Store_Other) _then) = _$Store_OtherCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$Store_OtherCopyWithImpl<$Res>
    implements $Store_OtherCopyWith<$Res> {
  _$Store_OtherCopyWithImpl(this._self, this._then);

  final Store_Other _self;
  final $Res Function(Store_Other) _then;

/// Create a copy of Store
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(Store_Other(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
