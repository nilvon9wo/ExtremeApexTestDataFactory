/**
 * Coverage for `XFTY_DummySObjectBundle`, the container that preserves the shape
 * of a generated object graph.
 */
@IsTest
private class XFTY_DummySObjectBundleTest {

    @IsTest
    static void getListReturnsWhatWasPut() {
        // Arrange
        List<SObject> accounts = new List<SObject>{ new Account(Name = 'One') };
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();

        // Act
        XFTY_DummySObjectBundle returned = bundle.put(Account.Id, accounts);

        // Assert
        Assert.areEqual(bundle, returned, 'put should be chainable');
        Assert.areEqual(accounts, bundle.getList(Account.Id));
    }

    @IsTest
    static void getBundleReturnsTheNestedBundleThatWasPut() {
        // Arrange
        XFTY_DummySObjectBundle child = new XFTY_DummySObjectBundle();
        XFTY_DummySObjectBundle parent = new XFTY_DummySObjectBundle();

        // Act
        parent.put(Contact.AccountId, child);

        // Assert
        Assert.areEqual(child, parent.getBundle(Contact.AccountId));
    }

    @IsTest
    static void listAndBundleAreStoredIndependentlyForTheSameField() {
        // Arrange
        List<SObject> accounts = new List<SObject>{ new Account(Name = 'One') };
        XFTY_DummySObjectBundle child = new XFTY_DummySObjectBundle();

        // Act
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle()
                .put(Contact.AccountId, accounts)
                .put(Contact.AccountId, child);

        // Assert
        Assert.areEqual(accounts, bundle.getList(Contact.AccountId));
        Assert.areEqual(child, bundle.getBundle(Contact.AccountId));
    }

    @IsTest
    static void missingKeysReturnNull() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();

        // Act
        // nothing to act on - the assertions exercise the empty bundle directly

        // Assert
        Assert.isNull(bundle.getList(Account.Id));
        Assert.isNull(bundle.getBundle(Account.Id));
    }

    // getValue - walk a path without holding the intermediate bundles ----------

    @IsTest
    static void getValueReadsAOneHopAncestorFieldForARow() {
        // Arrange - two Contacts, each with its own parent Account carrying a distinct name
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, new List<SObject>{ new Contact(), new Contact() });
        bundle.put(Contact.AccountId, new List<SObject>{
                new Account(Name = 'Row Zero'), new Account(Name = 'Row One')
        });

        // Act
        Object rowOneName = bundle.getValue(new List<SObjectField>{ Contact.AccountId, Account.Name }, 1);

        // Assert
        Assert.areEqual('Row One', rowOneName, 'the parent aligned with row 1');
    }

    @IsTest
    static void getValueDescendsThroughEveryLeadingRelationshipHop() {
        // Arrange - Contact -> Account (sub-bundle) -> parent Account (list), only the deepest name set
        XFTY_DummySObjectBundle accountBundle = new XFTY_DummySObjectBundle();
        accountBundle.put(Account.ParentId, new List<SObject>{ new Account(Name = 'Grandparent') });
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.put(Contact.AccountId, accountBundle);

        // Act
        Object grandparentName = bundle.getValue(
                new List<SObjectField>{ Contact.AccountId, Account.ParentId, Account.Name }
        );

        // Assert
        Assert.areEqual('Grandparent', grandparentName);
    }

    @IsTest
    static void getValueReturnsNullWhenAHopWasNotGenerated() {
        // Arrange - the relationship the path asks for was never put
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, new List<SObject>{ new Contact() });

        // Act
        Object missing = bundle.getValue(new List<SObjectField>{ Contact.AccountId, Account.Name });

        // Assert
        Assert.isNull(missing, 'an ungenerated ancestor reads as null, it does not throw');
    }

    @IsTest
    static void getValueReturnsNullWhenTheRowIndexIsOutOfRange() {
        // Arrange - one parent, ask for row 5
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.put(Contact.AccountId, new List<SObject>{ new Account(Name = 'Only') });

        // Act
        Object outOfRange = bundle.getValue(new List<SObjectField>{ Contact.AccountId, Account.Name }, 5);

        // Assert
        Assert.isNull(outOfRange);
    }

    @IsTest
    static void getValueRejectsAPathTooShortToWalk() {
        // Arrange
        List<SObjectField> justAField = new List<SObjectField>{ Account.Name };
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        try {
            bundle.getValue(justAField);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }

        // Assert
        Assert.isNotNull(thrown, 'a path needs at least one relationship hop then the field to read');
    }
}
