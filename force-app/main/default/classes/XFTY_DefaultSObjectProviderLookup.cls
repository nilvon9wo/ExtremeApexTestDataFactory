@IsTest
public class XFTY_DefaultSObjectProviderLookup implements XFTY_DummySObjectProviderLookupIntf {
	private static final Map<SObjectType, Type> OUTLET_TYPE_BY_SOBJECT_TYPE
			= new Map<SObjectType, Type>{
					Account.SObjectType => XFTY_DefaultAccountDataProvider.class,
					Contact.SObjectType => XFTY_DefaultContactDataProvider.class,
					User.SObjectType => XFTY_DefaultUserDataProvider.class
			};

	private static final Map<SObjectType, XFTY_DummySobjectProviderIntf> OUTLET_INSTANCE_BY_SOBJECT_TYPE
			= new Map<SObjectType, XFTY_DummySobjectProviderIntf>();

	public XFTY_DummySobjectProviderIntf get(SObjectType sObjectType) {
		if (!OUTLET_INSTANCE_BY_SOBJECT_TYPE.containsKey(sObjectType)) {
			if (!(OUTLET_TYPE_BY_SOBJECT_TYPE.containsKey(sObjectType))) {
				new LookupException('No data provider found for : ' + sObjectType);
			}
			OUTLET_INSTANCE_BY_SOBJECT_TYPE.put(
					sObjectType,
					(XFTY_DummySobjectProviderIntf) (OUTLET_TYPE_BY_SOBJECT_TYPE.get(sObjectType)).newInstance()
			);
		}
		return OUTLET_INSTANCE_BY_SOBJECT_TYPE.get(sObjectType);
	}

	// --------------------------------------------------------------------------

	public class LookupException extends XFTY_DummySObjectFtyProviderException {
	}
}