/**
 * Coverage for `XFTY_DummySObjectBundle`, the container that preserves the shape
 * of a generated object graph.
 */
@IsTest
private class XFTY_DummySObjectBundleTest {

    @IsTest
    static void getListReturnsWhatWasPut() {
        List<SObject> accounts = new List<SObject>{ new Account(Name = 'One') };
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();

        XFTY_DummySObjectBundle returned = bundle.put(Account.Id, accounts);

        Assert.areEqual(bundle, returned, 'put should be chainable');
        Assert.areEqual(accounts, bundle.getList(Account.Id));
    }

    @IsTest
    static void getBundleReturnsTheNestedBundleThatWasPut() {
        XFTY_DummySObjectBundle child = new XFTY_DummySObjectBundle();
        XFTY_DummySObjectBundle parent = new XFTY_DummySObjectBundle();

        parent.put(Contact.AccountId, child);

        Assert.areEqual(child, parent.getBundle(Contact.AccountId));
    }

    @IsTest
    static void listAndBundleAreStoredIndependentlyForTheSameField() {
        List<SObject> accounts = new List<SObject>{ new Account(Name = 'One') };
        XFTY_DummySObjectBundle child = new XFTY_DummySObjectBundle();
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle()
                .put(Contact.AccountId, accounts)
                .put(Contact.AccountId, child);

        Assert.areEqual(accounts, bundle.getList(Contact.AccountId));
        Assert.areEqual(child, bundle.getBundle(Contact.AccountId));
    }

    @IsTest
    static void missingKeysReturnNull() {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        Assert.isNull(bundle.getList(Account.Id));
        Assert.isNull(bundle.getBundle(Account.Id));
    }
}
