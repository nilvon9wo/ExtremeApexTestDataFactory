@IsTest
public class XFTY_DefaultAccountDataProvider implements XFTY_DummySobjectProviderIntf {
	public static final String DEFAULT_NAME_PREFIX = 'Test Account Name';
	public static final String DEFAULT_INDUSTRY = 'Test Account Industry';
	public static final String DEFAULT_TYPE = 'Test Account Type';

	public static final String DEFAULT_SHIPPING_CITY = 'Test Shipping City Industry';
	public static final String DEFAULT_SHIPPING_COUNTRY = 'Germany';
	public static final String DEFAULT_SHIPPING_STREET = 'Test Shipping Street Industry';

	private static final SObjectField PRIMARY_TARGET_FIELD = Account.Id;

	private static final XFTY_DummySObjectMasterTemplate MASTER_TEMPLATE
			= new XFTY_DummySObjectMasterTemplate(PRIMARY_TARGET_FIELD)
					.put(Account.Name, new XFTY_DummyDefaultValueIncrementingString(DEFAULT_NAME_PREFIX))
					.put(Account.Industry, new XFTY_DummyDefaultValueExact(DEFAULT_INDUSTRY))
					.put(Account.ShippingStreet, new XFTY_DummyDefaultValueExact(DEFAULT_SHIPPING_STREET))
					.put(Account.ShippingCity, new XFTY_DummyDefaultValueExact(DEFAULT_SHIPPING_CITY))
					.put(Account.ShippingCountry, new XFTY_DummyDefaultValueExact(DEFAULT_SHIPPING_COUNTRY))
					.put(Account.Type, new XFTY_DummyDefaultValueExact(DEFAULT_TYPE));

//	private static final XFTY_DummySObjectMasterTemplate PERSON_TEMPLATE
//			= new XFTY_DummySObjectMasterTemplate(PRIMARY_TARGET_FIELD)
//					.put(Account.FirstName, new XFTY_DummyDefaultValueIncrementingString(DEFAULT_FIRST_NAME_PREFIX))
//					.put(Account.LastName, new XFTY_DummyDefaultValueIncrementingString(DEFAULT_LAST_NAME_PREFIX))
//					.put(Account.PersonHomePhone, new XFTY_DummyDefaultValueIncrementingString(DEFAULT_PHONE_NUMBER_PREFIX))
//					.put(Account.PersonMobilePhone, new XFTY_DummyDefaultValueIncrementingString(DEFAULT_PHONE_NUMBER_PREFIX))
//					.put(Account.PersonBirthdate, new XFTY_DummyDefaultValueExact(TODAY.addYears(-20)))
//					.put(Account.PersonMailingStreet, new XFTY_DummyDefaultValueExact(DEFAULT_MAILING_STREET))
//					.put(Account.PersonMailingCity, new XFTY_DummyDefaultValueExact(DEFAULT_MAILING_CITY))
//					.put(Account.PersonMailingCountry, new XFTY_DummyDefaultValueExact(DEFAULT_MAILING_COUNTRY));

	public SObjectField getPrimaryTargetField() {
		return PRIMARY_TARGET_FIELD;
	}

	public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
		return MASTER_TEMPLATE;
	}

	public XFTY_DummySObjectBundle createBundle(
			XFTY_DummySObjectProviderLookupIntf providerLookup,
			List<SObject> templateSObjectList,
			XFTY_InsertModeEnum insertMode,
			XFTY_InsertInclusivityEnum inclusivity
	) {

		// This is a bit hacky, but it allows us to control which template to use when creating a bundle.
		// We can use a different SObject field to control this, but the same master needs to be used for each
		// record at the top level of the bundle.
		// (Control at a deeper level has not been investigated, but it may be necessary to use a differed XFTY_DummySObjectFactoryOutletLookupIntf.)
		// Id requiredRecordTypeId = (Id) templateSObjectList[0].get(Account.RecordTypeId);
		XFTY_DummySObjectMasterTemplate masterTemplate =
//                (requiredRecordTypeId == PERSON_RECORD_TYPE_ID)
//                    ? PERSON_TEMPLATE :
                        MASTER_TEMPLATE;

		if (masterTemplate == null) {
			throw new XFTY_DummySObjectFtyProviderException('Unsupported Account Record Type: ');
		}

		return XFTY_DummySObjectFactory.createBundle(providerLookup, masterTemplate, templateSObjectList, insertMode, inclusivity);
	}
}