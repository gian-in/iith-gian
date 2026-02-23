import SectionTitle from "../Common/SectionTitle";
// import latestCourses from "./sample";
import SingleCourse from "./SingleCourse";
import { useEffect, useState } from "react";
import axios from "axios";
import { Link } from "react-router-dom";

const LatestCourses = () => {
  const [latestCourses, setLatestCourses] = useState([]);
  useEffect(() => {
    axios
      .get(`${import.meta.env.VITE_API_FP2}/courses/latest`)
      .then((res) => {
        setLatestCourses(res.data || []);
      })
      .catch((err) => {
        console.log(err);
      });
  }, []);

  const numEmptyCourses =
    latestCourses.length < 3 ? 3 - latestCourses.length : 0;
  return (
    <section
      id="latest-courses"
      className="bg-gray-light dark:bg-bg-color-dark py-32 md:py-36 lg:py-40 relative z-10"
    >
      <div className="container">
        <SectionTitle
          title="Upcoming Courses at IITH"
          paragraph={
            <Link to="/courses/phase4" className="text-primary hover:underline">
              View all courses
            </Link>
          }
          center
        />
        <div className="grid grid-cols-1 gap-x-8 gap-y-10 md:grid-cols-2 md:gap-x-6 lg:gap-x-8 xl:grid-cols-3">
          {latestCourses.map((course, index) => (
            <div key={index} className="w-full">
              <SingleCourse course={course} />
            </div>
          ))}
          {Array.from({ length: numEmptyCourses }).map((_, index) => (
            <SingleCourse key={`empty-${index}`} isEmpty />
          ))}
        </div>
      </div>
    </section>
  );
};

export default LatestCourses;
