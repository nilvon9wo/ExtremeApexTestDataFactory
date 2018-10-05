# ExtremeApexTestDataFactory
Library for centralising the creation of Salesforce Apex test data.

Any developer who spends any serious amount of time developing or fixing test code quickly discovers, creating your test data separately for each test -- especially in an environment heavy with integration tests, as SFDC usually is -- can quickly become a large problem.



While working on an SFDC project for a FMCG, updates to the workflows and validation rules caused about 2,000 tests to fail. Since each test was creating its own data, it took about a week to perform the cleanup. It may be a matter of "great minds think alike", but when I did the "Generate Data for Tests" trailhead, the TestFactory class looked strikingly familiar.



Anyway, it and some recent reddit threads got me (re)thinking how I do tests.



I had already evolved past creating my Test Factories exactly this way.

Among other things, I don't like god objects and really strive to minimise method parameters.

Also, not every test wants or needs the same data for the same objects.

And, not least, as I learned how to do real unit testing (not just integration testing pretending to be unit tests) on Salesforce, I wanted to be able to avoid touching the database.



So, I started creating an army of test factory classes which gave me the flexibility I wanted and needed.

But I still wasn't happy because now my test factories were starting to carry a lot of redundant code.

But I couldn't figure out how to solve the problem that different fields have different constraints and different SObjects have different relationships.



Lately I've been reading Bevilacqua-Linn M.'s Functional Programming Patterns in Scala and Clojure.

Unfortunately we can't directly use Scala on SFDC and Clojure is making my brain hurt, but the book is brilliant.

And, even though we can't even use lambdas on SFDC, just reading the book, which discusses moving from OOP pattterns to functional patterns, go me (re)thinking about patterns and how I might apply them in the OOP world.



And, I believe I have come up with a truly elegant solution for creating test factories, so that I can create factories that look like this:



@IsTest
public class SAMPLE_DummyContactFactoryOutlet implements TEST_DummySObjectFactoryOutletIntf {
	private static final SObjectField PRIMARY_TARGET_FIELD = Contact.Id;
	public static final String DEFAULT_FIRST_NAME_PREFIX = 'Contact First Name';
	public static final String DEFAULT_LAST_NAME_PREFIX = 'Contact Last Name';
	public static final String DEFAULT_EMAIL_PREFIX = 'test.contact';

    public SObjectField getPrimaryTargetField() {
    	return PRIMARY_TARGET_FIELD;
    }
    
    public TEST_DummySObjectBundle createBundle(
	    	List<SObject> templateSObjectList, 
	    	TEST_InsertModeEnum insertMode, 
	    	TEST_InsertInclusivityEnum inclusivity
	    ) {
    	TEST_DummySObjectMasterTemplate masterTemplate = new TEST_DummySObjectMasterTemplate(PRIMARY_TARGET_FIELD)
    		.put(Contact.FirstName, new TEST_DummyDefaultValueIncrementingString(DEFAULT_FIRST_NAME_PREFIX))
    		.put(Contact.LastName, new TEST_DummyDefaultValueIncrementingString(DEFAULT_LAST_NAME_PREFIX))
    		.put(Contact.Email, new TEST_DummyDefaultValueUniqueEmail(DEFAULT_EMAIL_PREFIX))
    		.put(Contact.AccountId, new TEST_DummyDefaultRelationshipRequired(new Account(
    			Description = 'Account for contact'
    		)));
    	return TEST_DummySObjectFactory.createBundle(masterTemplate, templateSObjectList, insertMode, inclusivity);
    }
} 

Right now, public interfaces are still pretty raw since I'm just focused on the core functionality and proof of concept.



Later, when I start making more use of it, I'll add some friendlier public interfaces which will hide the complexity from the consumer.



But there really isn't that much complexity to using it.

List<SObject> templateSObjectList just takes a list of SObject values boiled down the the values you actually care about for your test. If you don't care about any, this can be an empty list (and later, I will make a signature so you don't even need it).



XFTY_InsertModeEnum insertMode takes one of the following values

MOCK - creates Ids without touching the database

NEVER - does not create Ids

RELATED_ONLY - inserts the related records, but not (in this instance) the Contacts.

NOW - inserts both the record and the related records

LATER - technically the same as never but can be used to communicate intentions and possibly later prevent conflicts with mock insertions.



XFTY_InsertInclusivityEnum inclusivity takes one of the following values

ALL - Creates data for all related records.

REQUIRED - Creates data only for required related records

PREVENT_CASCADE - Only creates data for first level of related records.

NONE - Does not create related records.

This is really handy since many records are related to other records which you might not care about for your tests, but you may need to create them. This allows that to happen without littering your tests and being done redundantly all over the place. (And what if you need to update 2000 tests because Accounts now require Widgets?

And what happens when your Widgets require Dohickies?!



Slightly trickier than consuming the test factories is actually expanding them, but even that's pretty straight forward. You just need to put a new paired value into the master template.

The first value is the SObjectField you need/want to fill.

The second value extends one of two interfaces (hurry polymorphism! You don't need to care about this unless you want to create some more interfaces!), for which the following possibilities are currently supported:

XFTY_DummyDefaultRelationshipRequired - Required Relationships

XFTY_DummyDefaultRelationshipOptional - Optional Relationships

XFTY_DummyDefaultValueExact - Exact values

XFTY_DummyDefaultValueIncrementingString - Incrementing Strings (value can repeat)

XFTY_DummyDefaultValueUniqueEmail - Unique Emails (guaranteed to be unique)

XFTY_DummyDefaultValueUniqueString - Unique Strings (guaranteed to be unique)

If you new value wrapper (e.g. incrementing numbers, random numbers, etc.) it's just a new class and very few lines of code.



It's all actually not that complicated for all the power it gives you to keep your code clean and dry. :-)

