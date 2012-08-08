require 'spec_helper'

describe "empty db" do

  before :each do
    User.delete_all
    ReferralHierarchy.delete_all
  end

  context "empty db" do
    it "should return no entities" do
      User.roots.should be_empty
      User.leaves.should be_empty
    end
  end

  context "ReferralHierarchy" do
    it "sets table_name for the _hierarchy model" do
      ReferralHierarchy.table_name.should == "referral_hierarchies"
    end
  end

  context "1 user db" do
    it "should return the only entity as a root and leaf" do
      a = User.create!(:email => "me@domain.com")
      User.roots.should == [a]
      User.leaves.should == [a]
    end
  end

  context "2 user db" do
    it "should return a simple root and leaf" do
      root = User.create!(:email => "first@t.co")
      leaf = root.children.create!(:email => "second@t.co")
      User.roots.should == [root]
      User.leaves.should == [leaf]
    end
  end


  context "3 User collection.create db" do
    before :each do
      @root = User.create! :email => "poppy@t.co"
      @mid = @root.children.create! :email => "matt@t.co"
      @leaf = @mid.children.create! :email => "james@t.co"
      @root_id = @root.id
    end

    it "should create all Users" do
      User.all.should =~ [@root, @mid, @leaf]
    end

    it "should return a root and leaf without middle User" do
      User.roots.should == [@root]
      User.leaves.should == [@leaf]
    end

    it "should delete leaves" do
      User.leaves.destroy_all
      User.roots.should == [@root] # untouched
      User.leaves.should == [@mid]
    end

    it "should delete roots and maintain hierarchies" do
      User.roots.destroy_all
      assert_mid_and_leaf_remain
    end

    it "should root all children" do
      @root.destroy
      assert_mid_and_leaf_remain
    end

    def assert_mid_and_leaf_remain
      ReferralHierarchy.find_all_by_ancestor_id(@root_id).should be_empty
      ReferralHierarchy.find_all_by_descendant_id(@root_id).should be_empty
      @mid.ancestry_path.should == %w{matt@t.co}
      @leaf.ancestry_path.should == %w{matt@t.co james@t.co}
      @mid.self_and_descendants.should =~ [@mid, @leaf]
      User.roots.should == [@mid]
      User.leaves.should == [@leaf]
    end
  end

  it "supports users with contracts" do
    u = User.find_or_create_by_path(%w(a@t.co b@t.co c@t.co))
    u.descendant_ids.should == []
    u.ancestor_ids.should == [u.parent.id, u.root.id]
    u.root.descendant_ids.should == [u.parent.id, u.id]
    u.root.ancestor_ids.should == []
    c1 = u.contracts.create!
    c2 = u.parent.contracts.create!
    u.root.indirect_contracts.to_a.should =~ [c1, c2]
  end

  it "performs as the readme says it does" do
    grandparent = Tag.create(:name => 'Grandparent')
    parent = grandparent.children.create(:name => 'Parent')
    child1 = Tag.create(:name => 'First Child')
    parent.children << child1
    child2 = Tag.create(:name => 'Second Child')
    parent.add_child child2
    grandparent.self_and_descendants.collect(&:name).should ==
      ["Grandparent", "Parent", "First Child", "Second Child"]
    child1.ancestry_path.should ==
      ["Grandparent", "Parent", "First Child"]
    d = Tag.find_or_create_by_path %w(a b c d)
    h = Tag.find_or_create_by_path %w(e f g h)
    e = h.root
    d.add_child(e) # "d.children << e" would work too, of course
    h.ancestry_path.should == %w(a b c d e f g h)
  end
end
