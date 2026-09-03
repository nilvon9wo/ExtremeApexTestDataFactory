/**
 * Proves `XFTY_DummySObjectBundle`, the container that preserves the shape of a
 * generated object graph. Pure in-memory structure, no DML/SOQL.
 */
@IsTest
private class XFTY_DummySObjectBundleTest {

    // put / getList / getBundle -------------------------------------

    @IsTest
    static void testGetList_afterPut_returnsWhatWasPutAndPutIsChainable() {
        // Arrange
        List<SObject> accounts = new List<SObject>{ new Account(Name = 'One') };
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle returned = bundle.put(Account.Id, accounts);
        Test.stopTest();

        // Assert
        Assert.areEqual(bundle, returned, 'put is chainable');
        Assert.areEqual(accounts, bundle.getList(Account.Id));
    }

    @IsTest
    static void testGetBundle_afterPut_returnsTheNestedBundle() {
        // Arrange
        XFTY_DummySObjectBundle child = new XFTY_DummySObjectBundle();
        XFTY_DummySObjectBundle parent = new XFTY_DummySObjectBundle();

        // Act
        Test.startTest();
        parent.put(Contact.AccountId, child);
        Test.stopTest();

        // Assert
        Assert.areEqual(child, parent.getBundle(Contact.AccountId));
    }

    @IsTest
    static void testGetListAndGetBundle_forTheSameField_areStoredIndependently() {
        // Arrange
        List<SObject> accounts = new List<SObject>{ new Account(Name = 'One') };
        XFTY_DummySObjectBundle child = new XFTY_DummySObjectBundle();

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle()
                .put(Contact.AccountId, accounts)
                .put(Contact.AccountId, child);
        Test.stopTest();

        // Assert
        Assert.areEqual(accounts, bundle.getList(Contact.AccountId));
        Assert.areEqual(child, bundle.getBundle(Contact.AccountId));
    }

    @IsTest
    static void testGetList_forAMissingKey_returnsNull() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();

        // Act
        Test.startTest();
        List<SObject> missing = bundle.getList(Account.Id);
        Test.stopTest();

        // Assert
        Assert.isNull(missing);
    }

    @IsTest
    static void testGetBundle_forAMissingKey_returnsNull() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle missing = bundle.getBundle(Account.Id);
        Test.stopTest();

        // Assert
        Assert.isNull(missing);
    }

    // getValue - delegates to XFTY_AncestorPathWalker (walk behaviour proven in XFTY_AncestorPathWalkerTest)

    @IsTest
    static void testGetValue_withARowIndex_walksFromThisBundleAtThatRow() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.put(Contact.AccountId, new List<SObject>{
                new Account(Name = 'Row Zero'), new Account(Name = 'Row One')
        });

        // Act
        Test.startTest();
        Object rowOneName = bundle.getValue(new List<SObjectField>{ Contact.AccountId, Account.Name }, 1);
        Test.stopTest();

        // Assert
        Assert.areEqual('Row One', rowOneName);
    }

    @IsTest
    static void testGetValue_withoutARowIndex_walksFromRowZero() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.put(Contact.AccountId, new List<SObject>{ new Account(Name = 'First') });

        // Act
        Test.startTest();
        Object firstName = bundle.getValue(new List<SObjectField>{ Contact.AccountId, Account.Name });
        Test.stopTest();

        // Assert
        Assert.areEqual('First', firstName);
    }

    // childRecordsOf - one primary's slice of the children -----------

    @IsTest
    static void testChildRecordsOf_forOneParentRow_returnsOnlyThatRowsChildren() {
        // Arrange - 2 parents; row 0 owns children A0 and A1, row 1 owns A2
        XFTY_DummySObjectBundle childBundle = new XFTY_DummySObjectBundle();
        childBundle.putPrimaries(Contact.Id, new List<SObject>{
                new Contact(LastName = 'A0'), new Contact(LastName = 'A1'), new Contact(LastName = 'A2')
        });
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Account.Id, new List<SObject>{ new Account(), new Account() });
        bundle.putChild(Contact.AccountId, childBundle, new List<Integer>{ 0, 0, 1 });

        // Act
        Test.startTest();
        List<SObject> rowOneChildren = bundle.childRecordsOf(1, Contact.AccountId);
        Test.stopTest();

        // Assert
        Assert.areEqual(1, rowOneChildren.size());
        Assert.areEqual('A2', ((Contact) rowOneChildren[0]).LastName);
    }

    @IsTest
    static void testChildRecordsOf_acrossTwoConfigsOnTheSameField_mergesInDeclarationOrder() {
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
        Test.startTest();
        List<SObject> rowZeroChildren = bundle.childRecordsOf(0, Contact.AccountId);
        Test.stopTest();

        // Assert
        Assert.areEqual(2, rowZeroChildren.size());
        Assert.areEqual('first', ((Contact) rowZeroChildren[0]).LastName, 'config declaration order');
        Assert.areEqual('second', ((Contact) rowZeroChildren[1]).LastName);
    }

    @IsTest
    static void testChildRecordsOf_whenTheFieldCarriesNoChildren_returnsAnEmptyList() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();

        // Act
        Test.startTest();
        List<SObject> none = bundle.childRecordsOf(0, Contact.AccountId);
        Test.stopTest();

        // Assert
        Assert.areEqual(0, none.size(), 'no children configured for that field');
    }

    // primariesResolvingTo - the inverse of the 1:1 parent alignment -

    @IsTest
    static void testPrimariesResolvingTo_whenPrimariesShareAnAncestor_returnsEveryPrimaryOnThatAncestor() {
        // Arrange - contacts 0 and 2 resolve to account 0, contact 1 to account 1
        Id accountZero = XFTY_IdMocker.generateId(Account.SObjectType);
        Id accountOne = XFTY_IdMocker.generateId(Account.SObjectType);
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, new List<SObject>{
                new Contact(LastName = 'C0', AccountId = accountZero),
                new Contact(LastName = 'C1', AccountId = accountOne),
                new Contact(LastName = 'C2', AccountId = accountZero)
        });
        bundle.put(Contact.AccountId, new List<SObject>{
                new Account(Id = accountZero), new Account(Id = accountOne)
        });

        // Act
        Test.startTest();
        List<SObject> onAccountZero = bundle.primariesResolvingTo(Contact.AccountId, 0);
        Test.stopTest();

        // Assert
        Assert.areEqual(2, onAccountZero.size());
        Assert.areEqual('C0', ((Contact) onAccountZero[0]).LastName);
        Assert.areEqual('C2', ((Contact) onAccountZero[1]).LastName);
    }

    @IsTest
    static void testPrimariesResolvingTo_whenNoIdsExist_fallsBackToPositionalAlignment() {
        // Arrange - no Ids anywhere, so ancestor row N pairs with primary row N
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, new List<SObject>{
                new Contact(LastName = 'C0'), new Contact(LastName = 'C1')
        });
        bundle.put(Contact.AccountId, new List<SObject>{ new Account(), new Account() });

        // Act
        Test.startTest();
        List<SObject> onRowOne = bundle.primariesResolvingTo(Contact.AccountId, 1);
        Test.stopTest();

        // Assert
        Assert.areEqual(1, onRowOne.size());
        Assert.areEqual('C1', ((Contact) onRowOne[0]).LastName);
    }

    @IsTest
    static void testPrimariesResolvingTo_whenTheAncestorRowIsOutOfRange_returnsAnEmptyList() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, new List<SObject>{ new Contact(LastName = 'C0') });
        bundle.put(Contact.AccountId, new List<SObject>{ new Account() });

        // Act
        Test.startTest();
        List<SObject> none = bundle.primariesResolvingTo(Contact.AccountId, 5);
        Test.stopTest();

        // Assert
        Assert.areEqual(0, none.size());
    }
}
