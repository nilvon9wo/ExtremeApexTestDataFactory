/**
 * Runnable proof for docs/use/sobject-injector.md - every `@IsTest` method is one
 * fenced example from that page. Pure in-memory, no DML/SOQL.
 */
@IsTest
private class XFTY_Ex_SObjectInjectorTest {

    @IsTest
    static void testResult_graftsAParentAndAForcedSystemField() {
        // Arrange
        List<Contact> contacts = new List<Contact>{ new Contact(LastName = 'Buyer') };
        List<SObject> accounts = new List<SObject>{ new Account(Name = 'Acme') };

        // Act
        Test.startTest();
        List<Contact> enriched = (List<Contact>) XFTY_SObjectInjector.inject(contacts)
                .relationship('Account', accounts)
                .value(Contact.CreatedDate, Datetime.newInstance(2024, 1, 1, 9, 0, 0))
                .result();
        Test.stopTest();

        // Assert
        Assert.areEqual('Acme', enriched[0].Account.Name);
        Assert.areEqual(Datetime.newInstance(2024, 1, 1, 9, 0, 0), enriched[0].CreatedDate);
    }

    @IsTest
    static void testResult_graftsAPolymorphicParentKeepingItsType() {
        // Arrange
        List<Task> tasks = new List<Task>{ new Task(Subject = 'Call') };

        // Act
        Test.startTest();
        List<Task> enriched = (List<Task>) XFTY_SObjectInjector.inject(tasks)
                .relationship('Who', new List<SObject>{ new Contact(LastName = 'Lead') })
                .result();
        Test.stopTest();

        // Assert
        Assert.isInstanceOfType(enriched[0].Who, Contact.class);
        Assert.areEqual('Lead', ((Contact) enriched[0].Who).LastName);
    }

    @IsTest
    static void testResult_graftsAChildSubqueryPerRow() {
        // Arrange
        List<Account> accounts = new List<Account>{ new Account(Name = 'Zero'), new Account(Name = 'One') };
        List<List<SObject>> contactsPerAccount = new List<List<SObject>>{
                new List<SObject>{ new Contact(LastName = 'A'), new Contact(LastName = 'B') },
                new List<SObject>{ new Contact(LastName = 'C') }
        };

        // Act
        Test.startTest();
        List<Account> enriched = (List<Account>) XFTY_SObjectInjector.inject(accounts)
                .childRelationship('Contacts', contactsPerAccount)
                .result();
        Test.stopTest();

        // Assert
        Assert.areEqual(2, enriched[0].Contacts.size());
        Assert.areEqual('C', enriched[1].Contacts[0].LastName);
    }

    @IsTest
    static void testResult_graftsANestedSubquery() {
        // Arrange
        List<Account> accounts = new List<Account>{ new Account(Name = 'Root') };
        List<Contact> contactsWithCases = (List<Contact>) XFTY_SObjectInjector.inject(
                new List<SObject>{ new Contact(LastName = 'Owner') }
        )
                .childRelationship('Cases', new List<List<SObject>>{ new List<SObject>{ new Case(Subject = 'x') } })
                .result();

        // Act
        Test.startTest();
        List<Account> enriched = (List<Account>) XFTY_SObjectInjector.inject(accounts)
                .childRelationship('Contacts', new List<List<SObject>>{ contactsWithCases })
                .result();
        Test.stopTest();

        // Assert
        Assert.areEqual('x', enriched[0].Contacts[0].Cases[0].Subject);
    }

    @IsTest
    static void testResult_forcesUniformAndPerRowValues() {
        // Arrange
        List<Account> accounts = new List<Account>{ new Account(Name = 'A'), new Account(Name = 'B') };

        // Act
        Test.startTest();
        List<Account> enriched = (List<Account>) XFTY_SObjectInjector.inject(accounts)
                .value(Account.CreatedById, UserInfo.getUserId())
                .valuePerRow(Account.AnnualRevenue, new List<Object>{ 100, 250 })
                .result();
        Test.stopTest();

        // Assert
        Assert.areEqual(UserInfo.getUserId(), enriched[0].CreatedById);
        Assert.areEqual(250, enriched[1].AnnualRevenue);
    }

    @IsTest
    static void testResult_forcesACompoundFieldFromAComponentMap() {
        // Arrange
        List<Contact> contacts = new List<Contact>{ new Contact(LastName = 'X') };

        // Act
        Test.startTest();
        List<Contact> enriched = (List<Contact>) XFTY_SObjectInjector.inject(contacts)
                .value(Contact.MailingAddress, new Map<String, Object>{ 'city' => 'Portland', 'street' => '2 Oak St' })
                .result();
        Test.stopTest();

        // Assert
        Address a = (Address) enriched[0].MailingAddress;
        Assert.areEqual('Portland', a.getCity());
        Assert.areEqual('2 Oak St', a.getStreet());
    }

    @IsTest
    static void testResult_carriesABlobFieldAcrossTheRoundTrip() {
        // Arrange
        List<Attachment> attachments = new List<Attachment>{ new Attachment(Name = 'f.txt') };

        // Act
        Test.startTest();
        List<Attachment> enriched = (List<Attachment>) XFTY_SObjectInjector.inject(attachments)
                .value(Attachment.Body, Blob.valueOf('file contents'))
                .value(Attachment.CreatedDate, Datetime.newInstance(2024, 1, 1, 0, 0, 0))
                .result();
        Test.stopTest();

        // Assert
        Assert.areEqual('file contents', enriched[0].Body.toString());
    }
}
