/**
 * Proves `XFTY_SObjectInjector` - the JSON round-trip that writes what
 * `record.put(...)` rejects. Pure in-memory, no DML/SOQL.
 */
@IsTest
private class XFTY_SObjectInjectorTest {

    @IsTest
    static void testResult_whenAParentIsGrafted_theRelationshipObjectIsReadableOnEachRow() {
        // Arrange
        List<Contact> contacts = new List<Contact>{ new Contact(LastName = 'Zero'), new Contact(LastName = 'One') };
        List<SObject> accounts = new List<SObject>{ new Account(Name = 'Acme'), new Account(Name = 'Globex') };

        // Act
        Test.startTest();
        List<Contact> enriched = (List<Contact>) XFTY_SObjectInjector.inject(contacts)
                .relationship('Account', accounts)
                .result();
        Test.stopTest();

        // Assert
        Assert.areEqual('Acme', enriched[0].Account.Name);
        Assert.areEqual('Globex', enriched[1].Account.Name);
    }

    @IsTest
    static void testResult_whenAParentEntryIsNull_leavesThatRowsRelationshipNull() {
        // Arrange
        List<Contact> contacts = new List<Contact>{ new Contact(LastName = 'Zero'), new Contact(LastName = 'One') };
        List<SObject> accounts = new List<SObject>{ new Account(Name = 'Acme'), null };

        // Act
        Test.startTest();
        List<Contact> enriched = (List<Contact>) XFTY_SObjectInjector.inject(contacts)
                .relationship('Account', accounts)
                .result();
        Test.stopTest();

        // Assert
        Assert.areEqual('Acme', enriched[0].Account.Name);
        Assert.isNull(enriched[1].Account);
    }

    @IsTest
    static void testResult_whenAChildRelationshipIsGrafted_theSubqueryIsReadable() {
        // Arrange
        List<Account> accounts = new List<Account>{ new Account(Name = 'Parent') };
        List<List<SObject>> contactsPerRow = new List<List<SObject>>{
                new List<SObject>{ new Contact(LastName = 'A'), new Contact(LastName = 'B') }
        };

        // Act
        Test.startTest();
        List<Account> enriched = (List<Account>) XFTY_SObjectInjector.inject(accounts)
                .childRelationship('Contacts', contactsPerRow)
                .result();
        Test.stopTest();

        // Assert
        Assert.areEqual(2, enriched[0].Contacts.size());
        Assert.areEqual('A', enriched[0].Contacts[0].LastName);
    }

    @IsTest
    static void testResult_whenAChildRowHasNoChildren_theSubqueryIsEmptyNotNull() {
        // Arrange
        List<Account> accounts = new List<Account>{ new Account(Name = 'Childless') };
        List<List<SObject>> none = new List<List<SObject>>{ new List<SObject>() };

        // Act
        Test.startTest();
        List<Account> enriched = (List<Account>) XFTY_SObjectInjector.inject(accounts)
                .childRelationship('Contacts', none)
                .result();
        Test.stopTest();

        // Assert
        Assert.areEqual(0, enriched[0].Contacts.size());
    }

    @IsTest
    static void testResult_whenAUniformValueIsSet_everyRowHasIt() {
        // Arrange
        List<Account> accounts = new List<Account>{ new Account(Name = 'A'), new Account(Name = 'B') };
        Datetime created = Datetime.newInstance(2020, 1, 1, 3, 4, 5);

        // Act
        Test.startTest();
        List<Account> enriched = (List<Account>) XFTY_SObjectInjector.inject(accounts)
                .value(Account.CreatedDate, created)
                .result();
        Test.stopTest();

        // Assert
        Assert.areEqual(created, enriched[0].CreatedDate);
        Assert.areEqual(created, enriched[1].CreatedDate);
    }

    @IsTest
    static void testResult_whenPerRowValuesAreSet_eachRowHasItsOwn() {
        // Arrange
        List<Account> accounts = new List<Account>{ new Account(Name = 'A'), new Account(Name = 'B') };
        List<Object> revenues = new List<Object>{ 100, 250 };

        // Act
        Test.startTest();
        List<Account> enriched = (List<Account>) XFTY_SObjectInjector.inject(accounts)
                .valuePerRow(Account.AnnualRevenue, revenues)
                .result();
        Test.stopTest();

        // Assert
        Assert.areEqual(100, enriched[0].AnnualRevenue);
        Assert.areEqual(250, enriched[1].AnnualRevenue);
    }

    @IsTest
    static void testResult_always_leavesTheInputRecordsUntouchedAndReturnsNewInstances() {
        // Arrange
        Contact original = new Contact(LastName = 'Original');
        List<Contact> contacts = new List<Contact>{ original };

        // Act
        Test.startTest();
        List<Contact> enriched = (List<Contact>) XFTY_SObjectInjector.inject(contacts)
                .relationship('Account', new List<SObject>{ new Account(Name = 'Grafted') })
                .result();
        Test.stopTest();

        // Assert
        Assert.isNull(original.Account, 'the input record was not mutated');
        Assert.areNotEqual(original, enriched[0], 'the result is a new instance');
        Assert.areEqual('Grafted', enriched[0].Account.Name);
    }

    @IsTest
    static void testResult_whenTheRecordListIsEmpty_returnsAnEmptyList() {
        // Arrange
        List<Contact> none = new List<Contact>();

        // Act
        Test.startTest();
        List<SObject> enriched = XFTY_SObjectInjector.inject(none).result();
        Test.stopTest();

        // Assert
        Assert.areEqual(0, enriched.size());
    }

    @IsTest
    static void testInject_whenRecordsIsNull_throws() {
        // Arrange
        List<SObject> nothing = null;

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            XFTY_SObjectInjector.inject(nothing);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
    }

    @IsTest
    static void testResult_whenAParentListIsMisaligned_throws() {
        // Arrange
        List<Contact> contacts = new List<Contact>{ new Contact(LastName = 'Zero'), new Contact(LastName = 'One') };
        List<SObject> onlyOneAccount = new List<SObject>{ new Account(Name = 'Acme') };

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            XFTY_SObjectInjector.inject(contacts).relationship('Account', onlyOneAccount).result();
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('Account'), 'the message names the misaligned graft');
    }

    @IsTest
    static void testResult_whenPerRowValuesAreMisaligned_throws() {
        // Arrange
        List<Account> accounts = new List<Account>{ new Account(Name = 'A'), new Account(Name = 'B') };
        List<Object> tooFew = new List<Object>{ 1 };

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            XFTY_SObjectInjector.inject(accounts).valuePerRow(Account.AnnualRevenue, tooFew).result();
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
    }

    @IsTest
    static void testResult_whenAChildAlreadyCarriesItsOwnSubquery_theNestingSurvivesTheRoundTrip() {
        // Arrange - a Contact that already has its Cases populated (from a prior injector pass)
        List<Contact> contactsWithCases = (List<Contact>) XFTY_SObjectInjector.inject(
                new List<SObject>{ new Contact(LastName = 'Parent') }
        )
                .childRelationship('Cases', new List<List<SObject>>{
                        new List<SObject>{ new Case(Subject = 'grandchild') }
                })
                .result();
        List<Account> accounts = new List<Account>{ new Account(Name = 'Root') };

        // Act
        Test.startTest();
        List<Account> enriched = (List<Account>) XFTY_SObjectInjector.inject(accounts)
                .childRelationship('Contacts', new List<List<SObject>>{ contactsWithCases })
                .result();
        Test.stopTest();

        // Assert
        Assert.areEqual('grandchild', enriched[0].Contacts[0].Cases[0].Subject,
                'a two-level subquery survives serialize/deserialize');
    }

    @IsTest
    static void testResult_whenAPolymorphicRelationshipIsGrafted_itRoundTripsWithItsType() {
        // Arrange - Task.WhoId is polymorphic; the relationship name is 'Who'
        List<Task> tasks = new List<Task>{ new Task(Subject = 'Call') };
        List<SObject> whos = new List<SObject>{ new Contact(LastName = 'Lead') };

        // Act
        Test.startTest();
        List<Task> enriched = (List<Task>) XFTY_SObjectInjector.inject(tasks)
                .relationship('Who', whos)
                .result();
        Test.stopTest();

        // Assert
        Assert.isInstanceOfType(enriched[0].Who, Contact.class, 'the polymorphic parent keeps its concrete type');
        Assert.areEqual('Lead', ((Contact) enriched[0].Who).LastName);
    }

    @IsTest
    static void testResult_whenABlobFieldIsForced_itIsCarriedAcrossTheRoundTrip() {
        // Arrange - Blob can't pass through the JSON, so the injector captures and re-applies it
        List<Attachment> attachments = new List<Attachment>{ new Attachment(Name = 'f.txt') };

        // Act
        Test.startTest();
        List<Attachment> enriched = (List<Attachment>) XFTY_SObjectInjector.inject(attachments)
                .value(Attachment.Body, Blob.valueOf('injected'))
                .value(Attachment.CreatedDate, Datetime.newInstance(2020, 1, 1, 0, 0, 0))
                .result();
        Test.stopTest();

        // Assert
        Assert.areEqual('injected', enriched[0].Body.toString(), 'the forced Blob survives');
        Assert.areEqual(Datetime.newInstance(2020, 1, 1, 0, 0, 0), enriched[0].CreatedDate, 'and the round-trip still ran');
    }

    @IsTest
    static void testResult_whenARecordAlreadyHasABlob_theRoundTripKeepsIt() {
        // Arrange
        List<Attachment> attachments = new List<Attachment>{ new Attachment(Name = 'f', Body = Blob.valueOf('preset')) };

        // Act
        Test.startTest();
        List<Attachment> enriched = (List<Attachment>) XFTY_SObjectInjector.inject(attachments)
                .value(Attachment.LastModifiedDate, Datetime.newInstance(2021, 6, 1, 0, 0, 0))
                .result();
        Test.stopTest();

        // Assert
        Assert.areEqual('preset', enriched[0].Body.toString(), 'a pre-set Blob is not lost');
    }

    @IsTest
    static void testResult_whenACompoundFieldIsForced_itReadsBackThroughTheCompound() {
        // Arrange - a compound field takes a Map of its lowercase components
        List<Contact> contacts = new List<Contact>{ new Contact(LastName = 'X') };

        // Act
        Test.startTest();
        List<Contact> enriched = (List<Contact>) XFTY_SObjectInjector.inject(contacts)
                .value(Contact.MailingAddress, new Map<String, Object>{ 'city' => 'Portland', 'street' => '2 Oak St' })
                .result();
        Test.stopTest();

        // Assert - code under test reading contact.MailingAddress.getCity() works
        Address mailing = (Address) enriched[0].MailingAddress;
        Assert.areEqual('Portland', mailing.getCity());
        Assert.areEqual('2 Oak St', mailing.getStreet());
    }

    @IsTest
    static void testResult_whenGraftsSpanAllThreeKinds_appliesEveryOneInOneRoundTrip() {
        // Arrange
        List<Contact> contacts = new List<Contact>{ new Contact(LastName = 'Solo') };
        List<SObject> accounts = new List<SObject>{ new Account(Name = 'Parent') };
        List<List<SObject>> casesPerRow = new List<List<SObject>>{
                new List<SObject>{ new Case(Subject = 'child') }
        };
        Datetime created = Datetime.newInstance(2019, 6, 1, 0, 0, 0);

        // Act
        Test.startTest();
        List<Contact> enriched = (List<Contact>) XFTY_SObjectInjector.inject(contacts)
                .relationship('Account', accounts)
                .childRelationship('Cases', casesPerRow)
                .value(Contact.CreatedDate, created)
                .result();
        Test.stopTest();

        // Assert
        Assert.areEqual('Parent', enriched[0].Account.Name);
        Assert.areEqual('child', enriched[0].Cases[0].Subject);
        Assert.areEqual(created, enriched[0].CreatedDate);
    }
}
