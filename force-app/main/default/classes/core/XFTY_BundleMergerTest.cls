/**
 * Proves `XFTY_BundleMerger` - folding the sibling child bundles of one
 * relationship field into a single navigable bundle. Pure in-memory, no DML/SOQL.
 */
@IsTest
private class XFTY_BundleMergerTest {

    @IsTest
    static void testMerge_always_concatenatesEveryBundlesPrimariesInDeclarationOrder() {
        // Arrange
        XFTY_DummySObjectBundle first = contactBundle(new List<SObject>{ new Contact(LastName = 'A') });
        XFTY_DummySObjectBundle second = contactBundle(new List<SObject>{
                new Contact(LastName = 'B'), new Contact(LastName = 'C')
        });

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle merged = XFTY_BundleMerger.combine(new List<XFTY_DummySObjectBundle>{ first, second });
        Test.stopTest();

        // Assert
        List<SObject> primaries = merged.primaryRecords();
        Assert.areEqual(3, primaries.size());
        Assert.areEqual('A', ((Contact) primaries[0]).LastName);
        Assert.areEqual('C', ((Contact) primaries[2]).LastName, 'second bundle appended after the first');
    }

    @IsTest
    static void testMerge_whenABundleHasNoPrimaries_skipsItAndKeepsTheRest() {
        // Arrange
        XFTY_DummySObjectBundle empty = new XFTY_DummySObjectBundle();
        empty.primaryTargetField = Contact.Id;
        XFTY_DummySObjectBundle populated = contactBundle(new List<SObject>{ new Contact(LastName = 'Only') });

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle merged = XFTY_BundleMerger.combine(new List<XFTY_DummySObjectBundle>{ empty, populated });
        Test.stopTest();

        // Assert
        Assert.areEqual(1, merged.primaryRecords().size());
    }

    @IsTest
    static void testMerge_whenTheFirstBundleHasNoPrimaryTargetField_putsNoPrimaries() {
        // Arrange
        XFTY_DummySObjectBundle noField = new XFTY_DummySObjectBundle();
        XFTY_DummySObjectBundle withField = contactBundle(new List<SObject>{ new Contact(LastName = 'Ignored') });

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle merged = XFTY_BundleMerger.combine(new List<XFTY_DummySObjectBundle>{ noField, withField });
        Test.stopTest();

        // Assert
        Assert.isNull(merged.primaryRecords(), 'no primary field on the lead bundle means nothing to key primaries under');
    }

    @IsTest
    static void testMerge_whenAParentFieldIsInOneBundleOnly_carriesThatSubBundleThrough() {
        // Arrange
        XFTY_DummySObjectBundle child = contactBundle(new List<SObject>{ new Contact(LastName = 'Child') });
        child.put(Contact.AccountId, accountBundle(new List<SObject>{ new Account(Name = 'Parent') }));
        XFTY_DummySObjectBundle plain = contactBundle(new List<SObject>{ new Contact(LastName = 'Sibling') });

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle merged = XFTY_BundleMerger.combine(new List<XFTY_DummySObjectBundle>{ child, plain });
        Test.stopTest();

        // Assert
        List<SObject> parents = merged.getBundle(Contact.AccountId).primaryRecords();
        Assert.areEqual(1, parents.size());
        Assert.areEqual('Parent', ((Account) parents[0]).Name);
    }

    @IsTest
    static void testMerge_whenAParentFieldIsInBothBundles_combinesTheirParentPrimaries() {
        // Arrange
        XFTY_DummySObjectBundle first = contactBundle(new List<SObject>{ new Contact(LastName = 'One') });
        first.put(Contact.AccountId, accountBundle(new List<SObject>{ new Account(Name = 'Acme') }));
        XFTY_DummySObjectBundle second = contactBundle(new List<SObject>{ new Contact(LastName = 'Two') });
        second.put(Contact.AccountId, accountBundle(new List<SObject>{ new Account(Name = 'Globex') }));

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle merged = XFTY_BundleMerger.combine(new List<XFTY_DummySObjectBundle>{ first, second });
        Test.stopTest();

        // Assert
        List<SObject> parents = merged.getBundle(Contact.AccountId).primaryRecords();
        Assert.areEqual(2, parents.size(), 'both bundles contributed their generated parent');
    }

    static XFTY_DummySObjectBundle contactBundle(List<SObject> contacts) {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, contacts);
        return bundle;
    }

    static XFTY_DummySObjectBundle accountBundle(List<SObject> accounts) {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Account.Id, accounts);
        return bundle;
    }
}
