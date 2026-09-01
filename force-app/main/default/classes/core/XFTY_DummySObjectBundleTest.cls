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

    // childRecordsOf - one primary's slice of the children -------------------

    @IsTest
    static void childRecordsOfReturnsOnlyTheChildrenOfThatPrimaryRow() {
        // Arrange - 2 parents; row 0 owns children A0 and A1, row 1 owns A2
        XFTY_DummySObjectBundle childBundle = new XFTY_DummySObjectBundle();
        childBundle.putPrimaries(Contact.Id, new List<SObject>{
                new Contact(LastName = 'A0'), new Contact(LastName = 'A1'), new Contact(LastName = 'A2')
        });
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Account.Id, new List<SObject>{ new Account(), new Account() });
        bundle.putChild(Contact.AccountId, childBundle, new List<Integer>{ 0, 0, 1 });

        // Act
        List<SObject> rowOneChildren = bundle.childRecordsOf(1, Contact.AccountId);

        // Assert
        Assert.areEqual(1, rowOneChildren.size());
        Assert.areEqual('A2', ((Contact) rowOneChildren[0]).LastName);
    }

    @IsTest
    static void childRecordsOfMergesAcrossConfigsInDeclarationOrder() {
        // Arrange - two child configs on the same field, both with a child for parent row 0
        XFTY_DummySObjectBundle firstConfig = new XFTY_DummySObjectBundle();
        firstConfig.putPrimaries(Contact.Id, new List<SObject>{ new Contact(LastName = 'first') });
        XFTY_DummySObjectBundle secondConfig = new XFTY_DummySObjectBundle();
        secondConfig.putPrimaries(Contact.Id, new List<SObject>{ new Contact(LastName = 'second') });
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Account.Id, new List<SObject>{ new Account() });
        bundle.putChild(Contact.AccountId, firstConfig, new List<Integer>{ 0 });
        bundle.putChild(Contact.AccountId, secondConfig, new List<Integer>{ 0 });

        // Act
        List<SObject> rowZeroChildren = bundle.childRecordsOf(0, Contact.AccountId);

        // Assert
        Assert.areEqual(2, rowZeroChildren.size());
        Assert.areEqual('first', ((Contact) rowZeroChildren[0]).LastName, 'config declaration order');
        Assert.areEqual('second', ((Contact) rowZeroChildren[1]).LastName);
    }

    @IsTest
    static void childRecordsOfIsEmptyWhenTheFieldCarriesNoChildren() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();

        // Act
        List<SObject> none = bundle.childRecordsOf(0, Contact.AccountId);

        // Assert
        Assert.areEqual(0, none.size(), 'no children configured for that field');
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
