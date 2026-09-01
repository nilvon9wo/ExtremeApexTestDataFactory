/**
 * The bundled Business Account Provider.
 *
 * Record-type / Person-Account variants are handled with lookup keys and a
 * separate Provider, not by inspecting the template in `createBundle` - see
 * `test-support/` for a worked `PersonAccount` flavour + Provider, and
 * docs/extend/provider-variants.md.
 */
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
					.put(Account.Name, new XFTY_IncrementingStringExpression(DEFAULT_NAME_PREFIX))
					.put(Account.Industry, new XFTY_LiteralExpression(DEFAULT_INDUSTRY))
					.put(Account.ShippingStreet, new XFTY_LiteralExpression(DEFAULT_SHIPPING_STREET))
					.put(Account.ShippingCity, new XFTY_LiteralExpression(DEFAULT_SHIPPING_CITY))
					.put(Account.ShippingCountry, new XFTY_LiteralExpression(DEFAULT_SHIPPING_COUNTRY))
					.put(Account.Type, new XFTY_LiteralExpression(DEFAULT_TYPE));

	public SObjectField getPrimaryTargetField() {
		return PRIMARY_TARGET_FIELD;
	}

	public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
		return MASTER_TEMPLATE;
	}

	public XFTY_DummySObjectBundle createBundle(
			XFTY_GenerationContext context,
			List<SObject> templateSObjectList
	) {
		return XFTY_DummySObjectFactory.createBundle(context, MASTER_TEMPLATE, templateSObjectList);
	}
}
